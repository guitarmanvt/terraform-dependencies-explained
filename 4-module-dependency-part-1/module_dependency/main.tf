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