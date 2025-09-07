resource "random_string" "random_string" {
  length           = 5
  special          = false
  upper            = false
  lower            = true
  numeric          = true
}

output "random_test" {
  value = random_string.random_string.result
}