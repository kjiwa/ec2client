# ec2client.sh

Interactive AWS EC2 instance connection tool with support for SSH and AWS Systems Manager (SSM) Session Manager.

## Prerequisites

- AWS CLI configured with appropriate credentials
- SSH client
- AWS Systems Manager Session Manager plugin
- Appropriate IAM permissions for EC2 and SSM operations

## Usage

```
ec2client.sh [OPTIONS]

Optional:
  -t TAG_KEY        Tag key to filter instances
  -v TAG_VALUE      Tag value to filter instances
  -p PROFILE        AWS profile
  -r REGION         AWS region (default: us-east-2)
  -c METHOD         Connection method (ssh or ssm, default: ssm)
  -u USER           SSH user (default: ec2-user)
  -k KEYFILE        SSH private key file path
```

## Examples

Connect to any running instance using SSM:
```bash
./ec2client.sh
```

Filter by environment tag:
```bash
./ec2client.sh -t Environment -v production
```

Connect via SSH with specific key:
```bash
./ec2client.sh -t Team -v backend -c ssh -k ~/.ssh/mykey.pem
```

Use different AWS profile and region:
```bash
./ec2client.sh -t Environment -v staging -p myprofile -r us-west-2
```

## Sample Output

```
Searching for EC2 instances with Environment=production...

1. api-server-01 (i-0123456789abcdef0): 54.123.45.67
2. api-server-02 (i-0fedcba987654321): 54.123.45.68
3. worker-node-01 (i-0a1b2c3d4e5f6g7h8): 18.234.56.78
4. worker-node-02 (i-0h8g7f6e5d4c3b2a1): 18.234.56.79
5. database-primary (i-01234abcd5678efgh): no-public-ip

Select instance (1-5): 3
Connecting to i-0a1b2c3d4e5f6g7h8 via SSM...

Starting session with SessionId: user-0a1b2c3d4e5f6g7h8
sh-4.2$ 
```

## Connection Methods

### SSM (Default)
- No public IP required
- Uses AWS Systems Manager Session Manager
- Requires SSM agent running on instance
- Instance must have appropriate IAM role

### SSH
- Requires public IP address
- Requires SSH key file (specified with -k or default key)
- Port 22 must be accessible
- Security group must allow SSH access

## Notes

- Both tag key and tag value must be specified together
- SSH connections use agent forwarding (-A flag)
- Script validates dependencies before execution
- Only running instances are displayed
