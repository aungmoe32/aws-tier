data "aws_ami" "this" {
  most_recent = true
  owners      = var.owners

  dynamic "filter" {
    for_each = var.filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}
