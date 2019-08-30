resource "random_pet" "eater" {
  separator = " "
}

resource "random_pet" "food" {
  separator = " "
}

resource "random_integer" "length" {
  min = 5
  max = 10
}

resource "random_string" "nonsense_word" {
  length = random_integer.length.result
  special = false
  upper = false
  number = false
}
resource "null_resource" "lunch" {
  provisioner "local-exec" {
      command = "echo A ${random_pet.eater.id} ate a ${random_pet.food.id} and said '${random_string.nonsense_word.result}'.___"
  }
}
