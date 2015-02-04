def upgrade ta, td, a, d
  d['element_run_list_order'] = td['element_run_list_order']

  # Make sure that all nodes have the proper run list order for the dns-client
  # role
  nodes = NodeObject.find('roles:dns-client')
  nodes.each do |node|
    node.delete_from_run_list('dns-client')
    node.add_to_run_list('dns-client',
                         td['element_run_list_order']['dns-client'],
                         td['element_states']['dns-client'])
    node.save
  end

  return a, d
end

def downgrade ta, td, a, d
  d.delete('element_run_list_order')
  return a, d
end
