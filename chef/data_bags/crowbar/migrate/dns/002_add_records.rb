def upgrade ta, td, a, d
  a["records"] = {}
  return a, d
end

def downgrade ta, td, a, d
  a.delete "records"
  return a, d
end
