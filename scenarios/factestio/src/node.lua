local Node = {}
Node.__index = Node

function Node.new(name, data)
  return setmetatable({
    name = name,
    data = data or {},
    parent = nil,
    children = {},
  }, Node)
end

function Node:add(child)
  child.parent = self
  table.insert(self.children, child)
end

return Node
