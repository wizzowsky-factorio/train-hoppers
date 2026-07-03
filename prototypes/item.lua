local loader_item = table.deepcopy(data.raw["item"]["steel-chest"])

loader_item.name = "train-hopper-loader"
loader_item.place_result = "train-hopper-loader"
loader_item.stack_size = 20
loader_item.order = "z[train-hopper]-a[loader]"

data:extend({ loader_item })