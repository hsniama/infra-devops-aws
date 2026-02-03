data "aws_availability_zones" "azs" {} //obtiene la lista de zonas de disponibilidad en la región de AWS

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true // Activa nombres de host DNS para las instancias dentro del VPC.
  enable_dns_support   = true //Activa soporte de DNS para que las instancias tengan nombres resolvibles.

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" { // permite que las subnets públicas tengan acceso a Internet.
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true // Asigna automáticamente IPs públicas a las instancias lanzadas en estas subnets.

  tags = {
    Name                     = "${var.name_prefix}-public-${count.index}"
    "kubernetes.io/role/elb" = "1" # Subnets públicas (para balanceadores accesibles desde Internet).
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name                              = "${var.name_prefix}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1" # Subnets privadas (para balanceadores internos).
  }
}

resource "aws_route_table" "public" { // Crea una tabla de rutas para las subnets públicas.
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name_prefix}-rt-public"
  }
}

// Agrega una ruta en la tabla pública.
resource "aws_route" "public_inet" { //Esto es lo que da salida a Internet a las instancias en las subnets públicas.
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0" // Todo el tráfico (0.0.0.0/0) → se envía al Internet Gateway.
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" { //Asocia cada subnet pública con la tabla de rutas pública.
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id // Así, todas las subnets públicas heredan la ruta hacia Internet.
}
