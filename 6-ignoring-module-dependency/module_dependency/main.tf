resource "null_resource" "module_dependency" {
  triggers = {
    dependency = var.module_dependency
  }
}

resource "null_resource" "wakey" {
  provisioner "local-exec" {
    command = "echo Wakey wakey from ${var.module_name}___"
  }
}

resource "null_resource" "hello" {
  depends_on = [null_resource.wakey, null_resource.module_dependency]

  provisioner "local-exec" {
    command = "echo Hello from ${var.module_name}___"
  }
}

resource "null_resource" "hola" {
  depends_on = [null_resource.wakey, null_resource.module_dependency]

  provisioner "local-exec" {
    command = "echo Hola from ${var.module_name}___"
  }
}

resource "null_resource" "module_is_complete" {
  depends_on = [null_resource.hello, null_resource.hola]

  provisioner "local-exec" {
    command = "echo Module is complete: ${var.module_name}___"
  }
}