import boto3
import certbot.main
import datetime
import os
import shutil
import subprocess

# Let’s Encrypt acme-v02 server that supports wildcard certificates
CERTBOT_SERVER = 'https://acme-v02.api.letsencrypt.org/directory'

# Temp dir of Lambda runtime
CERTBOT_DIR = '/tmp/certbot'


def rm_tmp_dir():
    if os.path.exists(CERTBOT_DIR):
        try:
            shutil.rmtree(CERTBOT_DIR)
        except NotADirectoryError:
            os.remove(CERTBOT_DIR)


def read_file(path):
  with open(path, 'r') as file:
    contents = file.read()
  return contents


def find_existing_cert(domains):
    domains = frozenset(domains.split(','))

    client = boto3.client('acm')
    paginator = client.get_paginator('list_certificates')
    iterator = paginator.paginate(PaginationConfig={'MaxItems': 1000})

    for page in iterator:
        for cert in page['CertificateSummaryList']:
            cert = client.describe_certificate(CertificateArn=cert['CertificateArn'])
            sans = frozenset(cert['Certificate']['SubjectAlternativeNames'])
            if sans.issubset(domains):
                return cert

    return None


def should_provision(domains):
    existing_cert = find_existing_cert(domains)
    if existing_cert:
        now = datetime.datetime.now(datetime.timezone.utc)
        not_after = existing_cert['Certificate']['NotAfter']
        return (not_after - now).days <= 30
    else:
        return True


def provision_certs(email, domains):
    certbot_args = [
        # Override directory paths so script doesn't have to be run as root
        '--config-dir', CERTBOT_DIR,
        '--work-dir', CERTBOT_DIR,
        '--logs-dir', CERTBOT_DIR,

        # Obtain a cert but don't install it
        'certonly',

        # Run in non-interactive mode
        '--non-interactive',

        # Agree to the terms of service
        '--agree-tos',

        # Email of domain administrator
        '--email', email,

        # Use dns challenge with route53
        '--dns-route53',
        '--preferred-challenges', 'dns-01',

        # Use this server instead of default acme-v01
        '--server', CERTBOT_SERVER,

        # Domains to provision certs for (comma separated)
        '--domains', domains,
    ]

    print(f'[Certbot] Provisioning certs for: {domains}, with email: {email}')
    certbot.main.main(certbot_args)
    cert_dir = os.path.join(CERTBOT_DIR, 'live')
    domain_names = domains.split(',')[0]
    for dir in os.listdir(cert_dir):
        if dir in domain_names:
            path = os.path.join(cert_dir, dir)
            return {
                'certificate': read_file(path + 'cert.pem'),
                'private_key': read_file(path + 'privkey.pem'),
                'certificate_chain': read_file(path + 'chain.pem')
            }


# /tmp/certbot
# ├── live
# │   └── [domain]
# │       ├── README
# │       ├── cert.pem
# │       ├── chain.pem
# │       ├── fullchain.pem
# │       └── privkey.pem
def upload_certs(s3_bucket, s3_prefix):
    cert_dir = os.path.join(CERTBOT_DIR, 'live')
    upload_to_s3(s3_bucket, s3_prefix, cert_dir)
    # copy to archive folder
    now = datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    archive_s3_prefix = os.path.join("archive", s3_prefix, now)
    upload_to_s3(s3_bucket, archive_s3_prefix, CERTBOT_DIR)


def upload_to_s3(s3_bucket, s3_prefix, cert_dir):
    client = boto3.client('s3')
    print(f'[S3] Uploading certs: {cert_dir} => s3://{s3_bucket}/{s3_prefix}')
    for dirpath, _dirnames, filenames in os.walk(cert_dir):
        for filename in filenames:
            local_path = os.path.join(dirpath, filename)
            relative_path = os.path.relpath(local_path, cert_dir)
            s3_key = os.path.join(s3_prefix, relative_path)
            print(f'[S3] Uploading: {local_path} => s3://{s3_bucket}/{s3_key}')
            client.upload_file(local_path, s3_bucket, s3_key)


def upload_cert_to_acm(cert, domains):
    existing_cert = find_existing_cert(domains)
    certificate_arn = existing_cert['Certificate']['CertificateArn'] if existing_cert else None

    print(f'[ACM] Updating certs for {domains}, {certificate_arn}')
    client = boto3.client('acm')
    if certificate_arn:
        acm_response = client.import_certificate(
            CertificateArn=certificate_arn,
            Certificate=cert['certificate'],
            PrivateKey=cert['private_key'],
            CertificateChain=cert['certificate_chain']
        )
    else:
        acm_response = client.import_certificate(
            Certificate=cert['certificate'],
            PrivateKey=cert['private_key'],
            CertificateChain=cert['certificate_chain']
        )

    return None if certificate_arn else acm_response['CertificateArn']


def notify_via_sns(topic_arn, domains, certificate):
    process = subprocess.Popen(['openssl', 'x509', '-noout', '-text'],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
    stdout, stderr = process.communicate(certificate)

    client = boto3.client('sns')
    client.publish(TopicArn=topic_arn,
                   Subject='Issued new LetsEncrypt certificate',
                   Message='Issued new certificates for domains: ' + domains + '\n\n' + stdout,
                   )


def guarded_handler(event, context):
    # Contact email for LetsEncrypt notifications
    email = os.environ.get('EMAIL')
    # Domains that will be included in the certificate
    domains = os.environ.get('DOMAINS')
    # The S3 bucket to publish certificates
    s3_bucket = os.environ.get('S3_BUCKET')
    # The S3 key prefix to publish certificates
    s3_prefix = os.environ.get('S3_PREFIX')
    # The SNS ARN to publish notifications
    sns_arn = os.environ.get('SNS_ARN')

    if should_provision(domains):
        cert = provision_certs(email, domains)
        upload_certs(s3_bucket, s3_prefix) if s3_bucket else None
        upload_cert_to_acm(cert, domains)
        notify_via_sns(sns_arn, domains, cert['certificate']) if sns_arn else None

    return 'Certificates obtained and uploaded successfully.'


def lambda_handler(event, context):
    try:
        rm_tmp_dir()
        return guarded_handler(event, context)
    except Exception as e:
        print(f'Encountered an error while provisioning certs: {str(e)}')
        raise
    finally:
        rm_tmp_dir()
