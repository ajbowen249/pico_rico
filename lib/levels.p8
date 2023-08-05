pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

-->8
-- levels

-- asset types
at_underfill = 1

game_levels = {
  {
    name = "level 1",
    background_color = 12,
    assets = {
      {
        name = "level_floor",
        type = at_underfill,
        spline = "37,-166.72409057617188,-0.7519989013671875,-157.89453125,-0.725616455078125,-110.53113555908203,-0.828155517578125,-85.0422592163086,-0.7519989013671875,-85.0422592163086,-0.7519989013671875,-76.21269989013672,-0.725616455078125,-48.19500732421875,11.183868408203125,-42.68403625488281,26.55957794189453,-42.68403625488281,26.55957794189453,-39.70491027832031,34.87139129638672,-27.018783569335938,61.58518981933594,-18.024826049804688,75.21943664550781,-18.024826049804688,75.21943664550781,-15.631082534790039,78.84819412231445,-2.7071070671081543,78.0,-2.0,78.0,-2.0,78.0,-2.384185791015625e-07,78.0,72.05933380126953,77.66058731079102,73.0,78.0,73.0,78.0,84.69535827636719,82.21993637084961,85.0,94.0,93.0,98.0,93.0,98.0,93.8944320678711,98.44721603393555,96.35372161865234,100.69100952148438,105.0,98.0,105.0,98.0,114.99388885498047,94.88956832885742,116.94491577148438,94.07145690917969,126.0,94.0,126.0,94.0,139.993896484375,93.88956832885742,143.33071899414062,95.6159896850586,152.0,93.0,152.0,93.0,158.993896484375,90.88956451416016,157.97784423828125,90.2248764038086,167.0,91.0,167.0,91.0,188.993896484375,92.88956832885742,222.94473266601562,93.04546737670898,232.0,93.0,232.0,93.0,253.993896484375,92.88956832885742,271.2315979003906,69.4482650756836,287.0601501464844,57.60420227050781,287.0601501464844,57.60420227050781,304.66998291015625,44.42726135253906,335.00909423828125,2.5120620727539062,354.13739013671875,-2.48126220703125,354.13739013671875,-2.48126220703125,368.076904296875,-6.120086669921875,400.711669921875,-11.80889892578125,434.41021728515625,-16.2835693359375,434.41021728515625,-16.2835693359375,468.1087951660156,-20.75823974609375,502.8711242675781,-24.018783569335938,521.0657348632812,-22.801071166992188,521.0657348632812,-22.801071166992188,535.440185546875,-21.839035034179688,556.3289794921875,-22.850830078125,578.01513671875,-22.6602783203125,578.01513671875,-22.6602783203125,599.7012329101562,-22.4697265625,622.1847534179688,-21.076797485351562,639.748779296875,-15.3052978515625,639.748779296875,-15.3052978515625,653.4354248046875,-10.807891845703125,748.0767211914062,-21.465774536132812,846.5719604492188,-22.69158935546875,846.5719604492188,-22.69158935546875,945.0671997070312,-23.917404174804688,1047.4163818359375,-15.711166381835938,1076.5189208984375,26.51453399658203,1076.5189208984375,26.51453399658203,1111.9345703125,77.90015029907227,1117.1243896484375,100.69615745544434,1127.9586181640625,119.95756149291992,1127.9586181640625,119.95756149291992,1138.7928466796875,139.2189655303955,1155.271484375,154.94579315185547,1213.2646484375,192.19313049316406,1213.2646484375,192.19313049316406,1234.25146484375,205.67235565185547,1264.820556640625,230.87466430664062,1317.1585693359375,252.13462829589844,1317.1585693359375,252.13462829589844,1369.49658203125,273.39459228515625,1443.603759765625,290.71221923828125,1551.666748046875,288.4220275878906,1551.666748046875,288.4220275878906,1610.892333984375,287.16685485839844,1672.107666015625,280.4671936035156,1738.6260986328125,261.0617980957031,1738.6260986328125,261.0617980957031,1805.14453125,241.65640258789062,1876.966064453125,209.54523468017578,1957.4041748046875,157.467041015625,1957.4041748046875,157.467041015625,1978.244140625,143.97458267211914,1987.241455078125,117.75905990600586,2022.78759765625,83.33960723876953,2022.78759765625,83.33960723876953,2058.333740234375,48.92015838623047,2120.4287109375,6.296775817871094,2247.463623046875,-40.01139831542969,2247.463623046875,-40.01139831542969,2375.70849609375,-86.76063537597656,2496.8779296875,-119.14553833007812,2642.87548828125,-141.63467407226562,2642.87548828125,-141.63467407226562,2788.873046875,-164.12380981445312,2959.698486328125,-176.71710205078125,3187.255126953125,-183.88287353515625,3187.255126953125,-183.88287353515625,3512.40869140625,-194.12197875976562,3604.80078125,-196.91949462890625,3652.53173828125,-196.799560546875,3652.53173828125,-196.799560546875,3700.262939453125,-196.67962646484375,3703.3330078125,-193.64224243164062,3849.841796875,-192.21148681640625,3849.841796875,-192.21148681640625,4051.4111328125,-190.2430419921875,4134.6943359375,-190.95840454101562,4204.21240234375,-191.8082275390625,4204.21240234375,-191.8082275390625,4273.73046875,-192.65805053710938,4329.4833984375,-193.64224243164062,4475.9921875,-192.21148681640625,4475.9921875,-192.21148681640625,4677.5615234375,-190.2430419921875,4833.42431640625,-185.83511352539062,4949.818359375,-198.3079833984375,4949.818359375,-198.3079833984375,5066.21240234375,-210.78085327148438,5143.1376953125,-240.134521484375,5186.83203125,-305.689208984375,5186.83203125,-305.689208984375,5257.33984375,-411.4725341796875,5332.48583984375,-561.9086303710938,5397.6923828125,-702.6862182617188,5397.6923828125,-702.6862182617188,5462.89892578125,-843.4638061523438,5518.166015625,-974.5830078125,5548.916015625,-1041.732666015625",
        color = 2,
      },
    },
  }
}

loading_level_state = nil

-- loading states
ls_init = 1
ls_load = 2

function load_level(level)
  game_mode = gm_loading_level
  loading_level_state = {
    level = level,
    loading_asset = 1,
    loading_state = ls_init,
  }

  level_state = {
    level = level,
    assets = {},
    initialized = false,
  }
end

function draw_loading_level()
  cls()
  local level = game_levels[loading_level_state.level]
  local asset_def = level.assets[loading_level_state.loading_asset]

  print("loading level " .. level.name, 0, 0, 6)
  print("asset: " .. asset_def.name, 0, 7, 6)
end

function update_loading_level()
  local level = game_levels[loading_level_state.level]
  if loading_level_state.loading_state == ls_init then
    loading_level_state.loading_state = ls_load
  elseif loading_level_state.loading_state == ls_load then
    local asset_def = level.assets[loading_level_state.loading_asset]
    local asset = { }

    if asset_def.type == at_underfill then
      asset.color = asset_def.color
      local spline = bez_spline_from_string(asset_def.spline)
      asset.points = spline:sample_with_fixed_length(bezier_spline_sample_incr)
      -- asset.points = spline:sample(bezier_spline_sample_incr)
    end

    level_state.assets[#level_state.assets + 1] = asset

    loading_level_state.loading_asset += 1
    if loading_level_state.loading_asset > #level.assets then
      begin_level(loading_level_state.level)
    end
  end
end