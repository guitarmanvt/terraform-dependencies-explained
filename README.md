# Terraform Dependencies, Explained

## Motivation

In a dream world, there would be no dependencies, and you could have everything you want immediately with a snap of your fingers.

In the real world, infrastructure components take time to spin up, and they sometimes depend on other components being an a usable state.

Terraform has some rudimentary support for dependencies between `resource`s. Unfortunately, there is no explicit support for dependencies between `module`s.

These examples exist to document how Terraform dependencies work, and how you can bend them to real-world needs.

## Example Code

Each module is included with full Terraform example code in an appropriately-named subdirectory.

### The convenient way

You can run these examples using the convenient `run` script provided. For example:

    ./run 1-resources-without-dependencies/

### The hard way

You can run the examples as you would expect:

    cd sub-directory
    terraform init
    terraform apply

The full Terraform output is really noisy, so this document doesn't include all of the output. It only includes lines that are printed (`echo`ed) with three trailing underscores (`___`). As a convenience, you can run the following command to just see the printed output:

    terraform apply --auto-accept | grep '___$'

You may run each example multiple times, but you will need to either run `terraform destroy` or `rm *tfstate*` before running the next `terraform apply`.


## Table of Contents

1. [Resources without Dependencies (aka, Dream World)](#1-resources-without-dependencies-aka-dream-world)
2. [Resources with Dependencies on other Resources (aka, Terraform's rudimentary support for dependencies)](#2-resources-with-dependencies-on-other-resources-aka-terraforms-rudimentary-support-for-dependencies)
3. [Implied Dependencies: Hooking Outputs into Inputs](#3-implied-dependencies-hooking-outputs-into-inputs)
4. [Faking Module Dependencies, part 1: Using a `module_dependency` Input](#4-faking-module-dependencies-part-1-using-a-module_dependency-input)
5. [Faking Module Dependencies, part 2: Using a `module_complete` Output](#5-faking-module-dependencies-part-2-using-a-module_complete-output)
6. [Module Resources that ignore Module Dependencies](#6-module-resources-that-ignore-module-dependencies)
7. [Module Resources that happen after `module_complete`](#7-module-resources-that-happen-after-module_complete)
8. [Making a Module depend on Multiple Dependencies](#8-making-a-module-depend-on-multiple-dependencies)
9. [A full example](#9-a-full-example)
10. [BONUS: Forcing a `resource` to run every time](#10-bonus-forcing-a-resource-to-run-every-time)

## The Examples

### 1. Resources without Dependencies (aka, Dream World)

When there is no dependency between `resource`s, Terraform will execute them in an undefined order. (This is probably based on a hash value somewhere, or perhaps on threading/process spawning considerations. I'd actually vote for the latter, since Terraform is written in Golang.)

The output will vary across runs, but often you'll see it out of order, like this:

    null_resource.three (local-exec): Hello, three___
    null_resource.one (local-exec): Hello, one___
    null_resource.two (local-exec): Hello, two___

### 2. Resources with Dependencies on other Resources (aka, Terraform's rudimentary support for dependencies)

Within a Terraform module, you can make the `resource`s depend on each other, using the `depends_on` attribute. Terraform will then be forced to create the resources in the order you expect.

I made the resources depend on each other, so that they are executed in numeric order. Here's the output:

    null_resource.one (local-exec): Hello, one___
    null_resource.two (local-exec): Hello, two___
    null_resource.three (local-exec): Hello, three___

### 3. Implied Dependencies: Hooking Outputs into Inputs

As far as I can tell, the `depends_on` attribute works the same under-the-hood as any other "implied" dependency: Terraform has to calculate the resource's ID before it can execute any resource that `depends_on` it.

At the risk of beating this to death, let's take another example. This time, we're going to pipe the outputs from some resources into other ones. We can chart this like a dependency graph:

* null_resource (which spits out the final output), gets some inputs from:
  * random_pet.eater
  * random_pet.food
  * random_string.nonsense, which gets an input from:
    * random_integer.length

Terraform cannot format the string in the `null_resource` until *after* it has determined two `random_pet` values and the `random_string`. But it can't generate the `random_string`, until it creates the `random_integer`. These implied dependencies must be resolved in the correct specific order before Terraform can output something like:

    null_resource.lunch (local-exec): A mutual bat ate a credible eagle and said 'qyfujpeuu'.___

**IMPORTANT NOTE:** If you are using existing modules, and you can use the `output` from one as the `input` to another, then _you get implied dependencies for free_, and you don't need anything else. The remaining examples are for those times when _implied dependencies aren't sufficient_.

### 4. Faking Module Dependencies, part 1: Using a `module_dependency` Input

This trick has two parts:

1. The dependent module must define a `module_dependency` input `variable`. This accepts a string value.
2. The required module must define an `output` that can be fed into the dependent module's `module_dependency` attribute.
  * For this example, the `output` value is taken from `null_resource.hello.id`.
  * In practice, you might choose a more meaningful output value, such as `ec2.instance.internal_ip_address`.
  * This choice actually matters significantly, which we'll look into more in Example 5.

The output is in the order you expect:

    module.a.null_resource.hello (local-exec): Hello from a___
    module.b.null_resource.hello (local-exec): Hello from b___
    module.c.null_resource.hello (local-exec): Hello from c___

### 5. Faking Module Dependencies, part 2: Using a `module_complete` Output

As mentioned in Example 4, at least one `output`s must be defined. If you can use an `output` from an existing `resource` or sub-module, great! However, there are times when this is not possible, including:

* The `resource` being created provides no (meaningful) `output`.
  * For example, `null_resource` provides only an `id` output, but that's not really usable as an `input` to anything.
* The `module` being called provides no (meaningful) `output`.
  * Sometimes, `module` authors simply don't specify any `output`s.
  * You can still use the `module`'s `id`, but again, that's not generally usable as an `input`.
* The `module`s being called and/or `resource`s being created need to *all* be finished before the module is truly complete.

The example code uses `null_resource.module_is_complete.id` in its `module_complete` `output` value. The `module_is_complete` will not itself be created until the other `null_resource`s in the module are complete; in this way, it can truly signal that the module has done everything it needs to do.

This is expressed in its simplest (simplistic?) form in the `module_complete_simplistic` output. However, with a little clever string interpolation, we can get a lot more information out of `module_complete`--including a "lineage". (We'll see this in greater detail in Example 9.)

You may also notice that "Hello" and "Hola" are non-deterministic, because they don't depend on each other. Terraform may select either one to perform first, but both are guaranteed to happen before `module_complete`.

Here's the output:

    module.a.null_resource.hello (local-exec): Hello from a___
    module.a.null_resource.hola (local-exec): Hola from a___
    module.a.null_resource.module_is_complete (local-exec): Module is complete: a___
    module.b.null_resource.hola (local-exec): Hola from b___
    module.b.null_resource.hello (local-exec): Hello from b___
    module.b.null_resource.module_is_complete (local-exec): Module is complete: b___
    module.c.null_resource.hola (local-exec): Hola from c___
    module.c.null_resource.hello (local-exec): Hello from c___
    module.c.null_resource.module_is_complete (local-exec): Module is complete: c___

This is the first example with outputs. Notice how the simplistic outputs show just an ID, while the others show the module name and its "lineage."

    a_module_complete = a(7392456150721315216)
    a_module_complete_simplistic = 7392456150721315216
    b_module_complete = a(7392456150721315216)->b(4018700161639813209)
    b_module_complete_simplistic = 4018700161639813209
    c_module_complete = a(7392456150721315216)->b(4018700161639813209)->c(7068680180823040759)
    c_module_complete_simplistic = 7068680180823040759

In the remaining examples, we will be using the "lineage" output style.

### 6. Module Resources that ignore Module Dependencies

Sometimes, you may have `resources` that Terraform can start building, without needing to wait for a module `dependency` to be ready. For example, you may need to obtain secrets from Vault that you will later need to upload to an EC2 instance; there's no need to wait for the EC2 instance to be available before you obtain the secrets.

In Example 6, we've added a `null_resource.wakey` that can happen at any time. In the output, you will notice that Terraform has chosen to run all the `wakey` resources before anything else. Also, because they are not dependent on a module `dependency`, they are executed in a non-deterministic order ("b, c, and a" in this run):

    module.b.null_resource.wakey (local-exec): Wakey wakey from b___
    module.c.null_resource.wakey (local-exec): Wakey wakey from c___
    module.a.null_resource.wakey (local-exec): Wakey wakey from a___
    module.a.null_resource.hola (local-exec): Hola from a___
    module.a.null_resource.hello (local-exec): Hello from a___
    module.a.null_resource.module_is_complete (local-exec): Module is complete: a___
    module.b.null_resource.hola (local-exec): Hola from b___
    module.b.null_resource.hello (local-exec): Hello from b___
    module.b.null_resource.module_is_complete (local-exec): Module is complete: b___
    module.c.null_resource.hello (local-exec): Hello from c___
    module.c.null_resource.hola (local-exec): Hola from c___
    module.c.null_resource.module_is_complete (local-exec): Module is complete: c___

Nevertheless, the module's "lineage" remains intact,  meaning that "a" really did complete before "b", which completed before "c".

    a_module_complete = a(1995119064313177372)
    b_module_complete = a(1995119064313177372)->b(5929110093258684117)
    c_module_complete = a(1995119064313177372)->b(5929110093258684117)->c(5469831016762839362)

### 7. Module Resources that happen after `module_complete`

Although I've yet to see it in the wild, it is possible to imagine situations when you might want to build a `resource` or call a `module` *after* a module completes.

In Example 7, the `whenever` resource can happen any time after a module is complete. In the output, you will notice that Terraform runs all the `whenever` resources after its `module_is_complete`; however, there is no guarantee beyond that.

    module.a.null_resource.hello (local-exec): Hello from a___
    module.a.null_resource.hola (local-exec): Hola from a___
    module.a.null_resource.module_is_complete (local-exec): Module is complete: a___
    module.a.null_resource.whenever (local-exec): Sometime after module is complete a___
    module.b.null_resource.hello (local-exec): Hello from b___
    module.b.null_resource.hola (local-exec): Hola from b___
    module.b.null_resource.module_is_complete (local-exec): Module is complete: b___
    module.b.null_resource.whenever (local-exec): Sometime after module is complete b___
    module.c.null_resource.hello (local-exec): Hello from c___
    module.c.null_resource.hola (local-exec): Hola from c___
    module.c.null_resource.module_is_complete (local-exec): Module is complete: c___
    module.c.null_resource.whenever (local-exec): Sometime after module is complete c___

Again, the "lineages" are still correct:

    a_module_complete = a(8170978353675315371)
    b_module_complete = a(8170978353675315371)->b(2804150941834387568)
    c_module_complete = a(8170978353675315371)->b(2804150941834387568)->c(6560025375423785318)


### 8. Making a Module depend on Multiple Dependencies

The `input` value `module_dependency` is a String. You can use the `join` function to merge multiple values together as a single dependency.

In this example, everything has been stripped down to show this. The critical line is in `module.c`:

    module_dependency = join(",", [module.b.module_complete, module.a.module_complete])

When we run this, Terraform may decide to create "b" before "a":

    module.b.null_resource.hello (local-exec): Hello from b___
    module.a.null_resource.hello (local-exec): Hello from a___
    module.b.null_resource.module_is_complete (local-exec): Module is complete: b___
    module.a.null_resource.module_is_complete (local-exec): Module is complete: a___
    module.c.null_resource.hello (local-exec): Hello from c___
    module.c.null_resource.module_is_complete (local-exec): Module is complete: c___


The output clearly shows that both "a" and "b" contributed to the "lineage" of "c", even though "b" came first:

    a_module_complete = a(4091150963373065818)
    b_module_complete = b(155490723100209537)
    c_module_complete = b(155490723100209537),a(4091150963373065818)->c(3345394125825183907)


### 9. A full example

This last example puts together every feature of module dependency:

1. Pre-dependency item 0 (which is likely to be created before anything else)
2. Dependent item 1, which depends on the Module `dependency`
3. Item 2, which depends on Item 1
3. Item 3, which is used to signal "Module Complete"
4. Post-completion items 4 and 5 (which are created in a non-deterministic order)

Here's the output:

    module.e.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in e___
    module.f.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in f___
    module.d.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in d___
    module.c.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in c___
    module.a.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in a___
    module.b.null_resource.ignores_dependency (local-exec): 0, may execute before module_dependency is met in b___
    module.e.null_resource.dependent_step_one (local-exec): 1 in e___
    module.a.null_resource.dependent_step_one (local-exec): 1 in a___
    module.d.null_resource.dependent_step_one (local-exec): 1 in d___
    module.e.null_resource.dependent_step_two (local-exec): 2 in e___
    module.a.null_resource.dependent_step_two (local-exec): 2 in a___
    module.d.null_resource.dependent_step_two (local-exec): 2 in d___
    module.e.null_resource.module_is_complete (local-exec): 3 in e: Module complete.___
    module.a.null_resource.module_is_complete (local-exec): 3 in a: Module complete.___
    module.d.null_resource.module_is_complete (local-exec): 3 in d: Module complete.___
    module.e.null_resource.after_complete_one (local-exec): 4, after module is complete in e___
    module.a.null_resource.after_complete_two (local-exec): 5, after module is complete in a___
    module.b.null_resource.dependent_step_one (local-exec): 1 in b___
    module.e.null_resource.after_complete_two (local-exec): 5, after module is complete in e___
    module.a.null_resource.after_complete_one (local-exec): 4, after module is complete in a___
    module.d.null_resource.after_complete_two (local-exec): 5, after module is complete in d___
    module.d.null_resource.after_complete_one (local-exec): 4, after module is complete in d___
    module.b.null_resource.dependent_step_two (local-exec): 2 in b___
    module.b.null_resource.module_is_complete (local-exec): 3 in b: Module complete.___
    module.b.null_resource.after_complete_one (local-exec): 4, after module is complete in b___
    module.b.null_resource.after_complete_two (local-exec): 5, after module is complete in b___
    module.c.null_resource.dependent_step_one (local-exec): 1 in c___
    module.c.null_resource.dependent_step_two (local-exec): 2 in c___
    module.c.null_resource.module_is_complete (local-exec): 3 in c: Module complete.___
    module.c.null_resource.after_complete_two (local-exec): 5, after module is complete in c___
    module.c.null_resource.after_complete_one (local-exec): 4, after module is complete in c___
    module.f.null_resource.dependent_step_one (local-exec): 1 in f___
    module.f.null_resource.dependent_step_two (local-exec): 2 in f___
    module.f.null_resource.module_is_complete (local-exec): 3 in f: Module complete.___
    module.f.null_resource.after_complete_two (local-exec): 5, after module is complete in f___
    module.f.null_resource.after_complete_one (local-exec): 4, after module is complete in f___

The lineages are shown as expected. Notice how "f" has an immediate dependency on "c,e" combined:

    a_module_complete = a(1781131692948656669)
    b_module_complete = a(1781131692948656669)->b(6179832578245004634)
    c_module_complete = a(1781131692948656669)->b(6179832578245004634)->c(8681313085439253073)
    d_module_complete = d(7373642148830847733)
    e_module_complete = e(3159336466918918596)
    f_module_complete = a(1781131692948656669)->b(6179832578245004634)->c(8681313085439253073),e(3159336466918918596)->f(5388520791376039416)

### 10. BONUS: Forcing a `resource` to run every time

A proper understanding of module dependencies will solve a lot of problems in Terraform. However, there are some `resource`s that cause a different kind of trouble in a moving environment. Two that have caused me problems are `file` and `null_resource`.

When you want a resource to build *every time you run `terraform apply`*, add this block to it:

    triggers = {
        build_number = "${timestamp()}"
    }

Pros:

* This `resource` will always be created (or updated if it was created before)
* You never have to `terraform taint` this `resource`

Cons:

* `terraform plan` will always tell you this `resource` needs to be updated
* conversely, `terraform plan` will never say that everything is as it should be
* `file` resources will overwrite any changes that have since been made to the `destination` file
* `remote-exec` and `local-exec` provisioners must be written in an idempotent manner, so that they do not redo work unnecessarily
* Any dependent `resource` or `module` will also be updated

## Boilerplate Module

You can apply this design to your own modules using the files in **boilerplate_module**.

## License

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
