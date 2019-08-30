resource "null_resource" "one" {
  provisioner "local-exec" {
      command = "echo Hello, one___"
  }
}

resource "null_resource" "two" {
  depends_on = [null_resource.one]
  provisioner "local-exec" {
      command = "echo Hello, two___"
  }
}

resource "null_resource" "three" {
  depends_on = [null_resource.two]
  provisioner "local-exec" {
      command = "echo Hello, three___"
  }
}