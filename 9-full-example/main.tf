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

# Modules d and e may be created at any time, even before a.
module "d" {
  source = "./module_dependency"

  module_name = "d"
}

module "e" {
  source = "./module_dependency"

  module_name = "e"
}


# Module f depends on both c and e.
module "f" {
  source = "./module_dependency"

  module_name = "f"
  module_dependency = join(",",[module.c.module_complete, module.e.module_complete])
}
