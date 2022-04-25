local list = fs.list("./Stillnet")

local output_file = fs.open("stillnet.pack","w")

for _,v in pairs(list) do
  local file = fs.open("./Stillnet/"..v,"r")
  output_file.write("\000\001\002")
  output_file.write(v)
  output_file.write("\n\n")
  output_file.write(file.readAll())
  output_file.write("\n\n")
  file.close()
end

output_file.close()
