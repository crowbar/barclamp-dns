def upgrade ta, td, a, d
  a['auto_assign_server'] = ta['auto_assign_server']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('auto_assign_server')
  return a, d
end
