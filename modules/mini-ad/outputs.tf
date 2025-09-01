
output "dns_server" {
  description = "DNS server IP address for the mini-ad deployment."
  value       = aws_instance.mini_ad_dc_instance.private_ip
}
