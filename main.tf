## resourcen gruppe erstellen
resource "azurerm_resource_group" "final_project_techstarter" { //id only for terraform 
  name     = "final_project_rg"
  location = "west Europe"
}
## azurerm_linux_virtual_machine -https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine


resource "azurerm_virtual_network" "TechstarterNetwork" {
  name                = "final_project_techstarter-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.final_project_techstarter.location
  resource_group_name = azurerm_resource_group.final_project_techstarter.name
}

resource "azurerm_subnet" "TechstarterNetwork" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.final_project_techstarter.name
  virtual_network_name = azurerm_virtual_network.TechstarterNetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}



##https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
## to create an ip address 
resource "azurerm_public_ip" "projpublicip" {
  name                = "proj-public-ip"
  resource_group_name = azurerm_resource_group.final_project_techstarter.name
  location            = azurerm_resource_group.final_project_techstarter.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}
#########################################################################################
resource "azurerm_network_interface" "proj" {
  name                = "proj-nic"
  location            = azurerm_resource_group.final_project_techstarter.location
  resource_group_name = azurerm_resource_group.final_project_techstarter.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.TechstarterNetwork.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.projpublicip.id // to get the ip address
  }
  depends_on = [azurerm_public_ip.projpublicip] // ip address
}

//network security group 
//https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
resource "azurerm_network_security_group" "final_project_techstarter" {
  name                = "final_project_techstarter.nsg"
  location            = azurerm_resource_group.final_project_techstarter.location
  resource_group_name = azurerm_resource_group.final_project_techstarter.name

}
// network security rule --sshd 
resource "azurerm_network_security_rule" "sshd" {
  name                        = "sshd"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.final_project_techstarter.name
  network_security_group_name = azurerm_network_security_group.final_project_techstarter.name
}

// network security rule --web 
resource "azurerm_network_security_rule" "web" {
  name                        = "web"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.final_project_techstarter.name
  network_security_group_name = azurerm_network_security_group.final_project_techstarter.name
}
// network security rule --allout
resource "azurerm_network_security_rule" "allout" {
  name                        = "allout"
  priority                    = 201
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.final_project_techstarter.name
  network_security_group_name = azurerm_network_security_group.final_project_techstarter.name
}
resource "azurerm_network_interface_security_group_association" "projnsg" {
  network_interface_id      = azurerm_network_interface.proj.id
  network_security_group_id = azurerm_network_security_group.final_project_techstarter.id

}
############################################################################################################

#Virtual Machine
resource "azurerm_linux_virtual_machine" "project" {
  name                = "project-vm"
  resource_group_name = azurerm_resource_group.final_project_techstarter.name
  location            = azurerm_resource_group.final_project_techstarter.location
  size                = "Standard_B1s"
  admin_username      = "techstarter"
  network_interface_ids = [
    azurerm_network_interface.proj.id,
  ]

  admin_ssh_key {
    username   = "techstarter"
    public_key = file("./ssh-key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  ##https://gmusumeci.medium.com/how-to-deploy-an-ubuntu-linux-vm-in-azure-using-terraform-d523731c39d3
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}
#####################################
//Storage account 
resource "azurerm_storage_account" "storage" {
  name                     = "storagestoracc"
  resource_group_name      = azurerm_resource_group.final_project_techstarter.name
  location                 = azurerm_resource_group.final_project_techstarter.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on               = [azurerm_resource_group.final_project_techstarter]
}

resource "azurerm_storage_container" "blobcontainer" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.storage]
}

#########################################
##Container Registry
resource "azurerm_container_registry" "final_project_rg" {
  name                = "containerDockerRegistary14000"
  resource_group_name = azurerm_resource_group.final_project_techstarter.name
  location            = azurerm_resource_group.final_project_techstarter.location
  sku                 = "Premium"
  admin_enabled       = false
  depends_on          = [azurerm_resource_group.final_project_techstarter]


}
resource "azurerm_container_registry_scope_map" "scope_map" {
  name                    = "container-scope-map"
  container_registry_name = azurerm_container_registry.final_project_rg.name
  resource_group_name     = azurerm_resource_group.final_project_techstarter.name
  actions = [
    "repositories/repo1/content/read",
    "repositories/repo1/content/write"
  ]
}

