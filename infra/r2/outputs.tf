output "bucket_names" {
  description = "Per-cluster R2 backup bucket names"
  value       = { for k, b in cloudflare_r2_bucket.backup : k => b.name }
}
