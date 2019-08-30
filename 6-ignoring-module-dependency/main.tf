# Modules a, b and c will be created in order a > b > c.
module "a" {
  source = "./module_dependency"

  module_name = "a"
}

module "b" {
  source = "./module_dependency"

  module_name = "b"
  module_dependency = module.a.module_complete
}

module "c" {
  source = "./module_dependency"

  module_name = "c"
  module_dependency = module.b.module_complete
}