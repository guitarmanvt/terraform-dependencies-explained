# Modules a, b and c will be created in order (a > b > c), OR (b > a > c).
module "a" {
  source = "./module_dependency"

  module_name = "a"
}

module "b" {
  source = "./module_dependency"

  module_name = "b"
}

module "c" {
  source = "./module_dependency"

  module_name = "c"
  module_dependency = join(",", [module.b.module_complete, module.a.module_complete])
}