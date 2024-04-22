# public-facing-ec2-tf

Terraform configuration for standing up a single EC2 instance which accepts incoming public traffic

Everything is hard-coded in `main.tf`, and it should be straightforward to understand what this does.

The EC2 instance would install `docker` and `git` via `user_data`.
