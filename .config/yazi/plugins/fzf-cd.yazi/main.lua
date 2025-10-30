-- Fuzzy find directory with tree preview and navigate
return {
	entry = function()
		-- Hide yazi UI to prevent overlap with fzf
		local permit = ya.hide()

		local cmd = "fd -H -t d | fzf --preview 'tree -C -L 2 {}'"
		local child, err = Command("sh")
			:arg("-c")
			:arg(cmd)
			:stdin(Command.INHERIT)
			:stdout(Command.PIPED)
			:stderr(Command.INHERIT)
			:spawn()

		if not child then
			if permit then
				permit:drop()
			end
			ya.err("Failed to spawn fzf: " .. tostring(err))
			return
		end

		local output, err = child:wait_with_output()

		-- Restore yazi UI
		if permit then
			permit:drop()
		end

		if not output or not output.status.success then
			return
		end

		local target = output.stdout:gsub("\n$", "")
		if target == "" or target == nil then
			return
		end

		ya.manager_emit("cd", { target })
	end,
}
