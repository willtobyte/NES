_G.engine = EngineFactory.new()
    :with_width(1024)
    :with_height(960)
    :with_scale(4.0)
    :create()

function setup()
    scenemanager:register("emulator")
    scenemanager:set("emulator")
end
