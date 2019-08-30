resource "null_resource" "one" {
  provisioner "local-exec" {
      command = "echo Hello, one___"
  }
}

resource "null_resource" "two" {
  provisioner "local-exec" {
      command = "echo Hello, two___"
  }
}

resource "null_resource" "three" {
  provisioner "local-exec" {
      command = "echo Hello, three___"
  }
}