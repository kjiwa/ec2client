# ec2client.sh

Connect to EC2 instances by environment tag using SSH or AWS Systems Manager (SSM).

## Requirements

- AWS CLI
- AWS Systems Manager Session Manager plugin
- SSH client
- Valid AWS credentials configured

## Usage

```bash
./ec2client.sh -e <environment> [OPTIONS]
```

### Required Parameters

- `-e ENVIRONMENT` - Environment tag value to filter instances

### Optional Parameters

- `-p PROFILE` - AWS profile name
- `-r REGION` - AWS region (default: us-east-2)
- `-c METHOD` - Connection method: `ssh` or `ssm` (default: ssm)
- `-u USER` - SSH user (default: ec2-user, only applies to ssh method)
- `-k KEYFILE` - Path to SSH private key file (only applies to ssh method)

## Examples

Connect via SSM to production environment:
```bash
./ec2client.sh -e prod
```

Connect via SSH with custom profile and key:
```bash
./ec2client.sh -e staging -p myprofile -c ssh -k ~/.ssh/mykey.pem
```

Connect to specific region:
```bash
./ec2client.sh -e test -r us-west-2
```

## Behavior

- Queries running EC2 instances with matching Environment tag
- Displays instances sorted alphabetically by name
- Auto-connects if only one instance found
- Prompts for selection if multiple instances found
- SSH method requires public IP address on instance
- SSM method works without public IP but requires SSM agent installed

## Exit Codes

- `0` - Successful connection
- `1` - Error (missing parameters, no instances found, connection failed)
