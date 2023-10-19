variable "az" {
    description = "avalability zone"
    default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    type = list(string)
}

variable "route-names" {
    description = "route names"
    default = ["public1", "public2", "public3"]
    type = list(string)
}

variable "cidrs" {
    description = "public cidr block"
    default = ["192.168.0.0/28", "192.168.0.16/28", "192.168.0.32/28"]
    type = list(string)
}

variable "vpc_cidr" {
    description = "vpc cidr block"
    default = "192.168.0.0/24"
    type = string

}
variable "public_subnet" {
    description = "public subnets"
    default = ["public-subnet1", "public-subnet2", "public-subnet3"] 
    type = list(string)
}

variable "private_subnet" {
    description = "private subnets"
    default = ["private-subnet1", "private-subnet2", "private-subnet3"]
    type = list(string)
}    

variable "privatecidrs" {
    description = "private cidr block"
    default = ["192.168.0.48/28", "192.168.0.64/28", "192.168.0.80/28"]
    type = list(string)
}

variable "nat_gateway" {
    description = "nat gateway"
    default = ["nat-gateway1", "nat-gateway2", "nat-gateway3"]
    type = list(string)
}