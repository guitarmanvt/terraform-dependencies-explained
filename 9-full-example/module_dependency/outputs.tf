output "module_complete" {
  description = "Module dependency that has been satisfied"
  value = "${var.module_dependency}${var.module_dependency == "" ? "" : "->"}${var.module_name}(${null_resource.module_is_complete.id})"
}
