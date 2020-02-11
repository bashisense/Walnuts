function tellme()
	io.write("Handler is coming from lua.tellme.\n")
end

function handler(reqstr)
    io.write("handler, request=")
    io.write(reqstr)
    io.write("\n")
	return(0)
end

print("handler running ...\n")