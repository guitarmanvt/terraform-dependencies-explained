resource "null_resource" "module_dependency" {
  triggers = {
    dependency = var.module_dependency
  }
}

resource "null_resource" "hello" {
  depends_on = [null_resource.module_dependency]

  provisioner "local-exec" {
    command = "echo Hello from ${var.module_name}___"
  }
}

resource "null_resource" "module_is_complete" {
  depends_on = [null_resource.hello]

  provisioner "local-exec" {
    command = "echo Module is complete: ${var.module_name}___"
  }
}