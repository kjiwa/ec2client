# ec2client.sh

Connect to EC2 instances by tag key-value pair using SSH or AWS Systems Manager (SSM).

## Requirements

- AWS CLI
- AWS Systems Manager Session Manager plugin
- SSH client
- Valid AWS credentials configured

## Usage

```bash
./ec2client.sh [OPTIONS]
```

### Optional Parameters

- `-t TAG_KEY` - Tag key to filter instances
- `-v TAG_VALUE` - Tag value to filter instances (required if -t is specified)
- `-p PROFILE` - AWS profile name
- `-r REGION` - AWS region (default: us-east-2)
- `-c METHOD` - Connection method: `ssh` or `ssm` (default: ssm)
- `-u USER` - SSH user (default: ec2-user, only applies to ssh method)
- `-k KEYFILE` - Path to SSH private key file (only applies to ssh method)

**Note:** If `-t` is specified, `-v` must also be specified (and vice versa). If neither is specified, all running instances in the region are queried.

## Examples

Connect to any running instance:
```bash
./ec2client.sh
```

Connect via SSM using Environment tag:
```bash
./ec2client.sh -t Environment -v prod
```

Connect via SSH with custom profile and key:
```bash
./ec2client.sh -t Environment -v staging -p myprofile -c ssh -k ~/.ssh/mykey.pem
```

Connect using custom tag:
```bash
./ec2client.sh -t Team -v backend -r us-west-2
```

## Behavior

- Queries running EC2 instances (optionally filtered by tag key-value pair)
- Displays instances sorted alphabetically by name
- Auto-connects if only one instance found
- Prompts for selection if multiple instances found
- SSH method requires public IP address on instance
- SSM method works without public IP but requires SSM agent installed

## Exit Codes

- `0` - Successful connection
- `1` - Error (missing parameters, no instances found, connection failed)
