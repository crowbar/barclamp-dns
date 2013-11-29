def upgrade ta, td, a, d
  a.delete 'contact'
  a.delete 'static'
  return a, d
end

def downgrade ta, td, a, d
  a['contact'] = 'support@pod.your.cloud.org'
  a['static'] = {}
  return a, d
end
