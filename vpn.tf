
resource "aws_vpc" "vpn_vpc" {
    cidr_block = "172.31.0.0/16"
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "VPN vpc"
    }
}
resource "aws_subnet" "main" {
    vpc_id     = aws_vpc.vpn_vpc.id
    cidr_block = "172.31.0.0/20"

    tags = {
        Name = "Main vpn subnet"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.vpn_vpc.id

    tags = {
        Name = "VPN internet gateway"
    }
}

/*resource "aws_egress_only_internet_gateway" "ipv6_gw" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "IPv6 Gateway"
  }
}*/

resource "aws_route_table" "internet_route_table" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  /*route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.ipv6_gw.id
  }*/

  tags = {
    Name = "VPN internet route"
  }
}

resource "aws_route_table_association" "internet_route_association" {
    subnet_id      = aws_subnet.main.id
    route_table_id = aws_route_table.internet_route_table.id
}


/*
Certificates can be generated and imported to aws acm as described here:
https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-authentication.html#mutual
*/
resource "aws_ec2_client_vpn_endpoint" "vpn_endpoint" {
  description            = "VPN-Client-Endpoint"
  server_certificate_arn = var.server_certificate_arn
  
  client_cidr_block      = "10.0.0.0/22"
  dns_servers = ["1.1.1.1","8.8.8.8"]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn =  var.client_certificate_arn #Certificate issued to client
    
  }

  connection_log_options {
    enabled               = false
    #cloudwatch_log_group  = aws_cloudwatch_log_group.lg.name
    #cloudwatch_log_stream = aws_cloudwatch_log_stream.ls.name
  }
}

resource "aws_ec2_client_vpn_network_association" "association" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
    subnet_id              = aws_subnet.main.id
}

resource "aws_ec2_client_vpn_authorization_rule" "auth_rule" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
    target_network_cidr    = aws_subnet.main.cidr_block
    authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_route" "internet_route" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
    destination_cidr_block = "0.0.0.0/0"
    target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.association.subnet_id
    description = "Internet route"
}
resource "aws_ec2_client_vpn_authorization_rule" "internet_access" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
    target_network_cidr    = "0.0.0.0/0"
    authorize_all_groups   = true
    description = "Internet access"
}
