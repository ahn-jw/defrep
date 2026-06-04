provider "azurerm" {
  features {}
}

# 기존에 구성된 VNet 및 서브넷 정보 가져오기 (환경에 맞게 수정)
data "azurerm_subnet" "existing_subnet" {
  name                 = "my-subnet"
  virtual_network_name = "defvmLinux-vnet"
  resource_group_name  = "defres"
}

# VM용 네트워크 인터페이스(NIC) 생성
resource "azurerm_network_interface" "vm_nic" {
  name                = "azure-app-nic"
  location            = "koreacentral"
  resource_group_name = "defres"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.existing_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 핵심: Cloud-init 파일 로드
data "file" "cloud_init" {
  filename = "${path.module}/cloud-init.txt"
}

# Azure VM 생성 및 OS 프로비저닝 데이터 주입
resource "azurerm_linux_virtual_machine" "azure_vm" {
  name                = "azure-app-server"
  resource_group_name = "my-resource-group"
  location            = "koreacentral"
  size                = "Standard_D2s_v5" # 필요 스펙에 맞게 조절
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  # 관리자 SSH 키 설정 (또는 패스워드 설정)
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # 표준 마켓플레이스 이미지 (Ubuntu 22.04 LTS)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # ★ 핵심: OS 커널에 Cloud-init 스크립트 전달 (Base64 인코딩 필수)
  custom_data = base64encode(data.file.cloud_init.content)
}