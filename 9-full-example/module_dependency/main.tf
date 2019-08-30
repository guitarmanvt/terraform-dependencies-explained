resource "null_resource" "module_dependency" {
  triggers = {
    dependency = var.module_dependency
  }
}

resource "null_resource" "ignores_dependency" {
  provisioner "local-exec" {
    command = "echo 0, may execute before module_dependency is met in ${var.module_name}___"
  }
}

resource "null_resource" "dependent_step_one" {
  depends_on = [null_resource.module_dependency]

  provisioner "local-exec" {
    command = "echo 1 in ${var.module_name}___"
  }
}

resource "null_resource" "dependent_step_two" {
  depends_on = [null_resource.dependent_step_one]

  provisioner "local-exec" {
    command = "echo 2 in ${var.module_name}___"
  }
}

resource "null_resource" "module_is_complete" {
  depends_on = [null_resource.dependent_step_one, null_resource.dependent_step_two]

  provisioner "local-exec" {
    command = "echo 3 in ${var.module_name}: Module complete.___"
  }
}

resource "null_resource" "after_complete_one" {
  depends_on = [null_resource.module_is_complete]

  provisioner "local-exec" {
    command = "echo 4, after module is complete in ${var.module_name}___"
  }
}

resource "null_resource" "after_complete_two" {
  depends_on = [null_resource.module_is_complete]

  provisioner "local-exec" {
    command = "echo 5, after module is complete in ${var.module_name}___"
  }
}
