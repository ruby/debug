require 'webrick'
require 'json'
obj_map = {}
srv = WEBrick::HTTPServer.new({ :DocumentRoot => './',
                                :BindAddress => '127.0.0.1',
                                :Port => 20080})
trap("INT"){ srv.shutdown }
srv.mount_proc('/svg'){|req, res|
  oid = req.query['id']
  if obj = obj_map[oid]
    res.content_type = 'image/svg+xml'
    res.body = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" height="100" width="100">
      <circle cx="50" cy="50" r="40" stroke="black" stroke-width="3" fill="red" />
      <text x="20" y="55" font-size="10">
        #{obj.inspect}
      </text>
    </svg>
    SVG
  else
    res.body = nil
  end
}
srv.mount_proc('/object'){|req, res|
  hash = JSON.parse req.body
  hash.each{|key, val|
    obj_map[key] = val
  }
}
srv.start
