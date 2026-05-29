output "vpc" {
  value = {
    vpc_id                = aws_vpc.this.id
    public_subnets        = aws_subnet.public[*].id
    private_subnets       = aws_subnet.private[*].id
    database_subnets      = aws_subnet.database[*].id
    database_subnet_group = aws_db_subnet_group.database.name
  }
}

output "sg" {
  value = {
    lb     = aws_security_group.lb_sg.id
    db     = aws_security_group.db_sg.id
    websvr = aws_security_group.websvr_sg.id
  }
}
