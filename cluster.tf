data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "main" {
  ami               = data.aws_ami.ubuntu.id
  availability_zone = "us-east-1a"
  instance_type     = "t3.small"
  subnet_id         = aws_subnet.example_subnet.id

  key_name = aws_key_pair.login.key_name

  vpc_security_group_ids = [
    aws_security_group.inbound_ssh_http.id
  ]
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install git -y
              sudo amazon-linux-extras install docker git -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo systemctl enable docker
              sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose
              EOF

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa") # Change this to the path of your private key
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
      "sudo systemctl enable docker"
    ]
  }

  user_data_replace_on_change = true

  associate_public_ip_address = true
}

resource "aws_key_pair" "login" {
  key_name   = "login-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
