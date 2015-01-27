def upgrade ta, td, a, d
  d['element_run_list_order'] = td['element_run_list_order']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('element_run_list_order')
  return a, d
end
