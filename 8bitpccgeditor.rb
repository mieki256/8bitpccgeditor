#!ruby -Ks
# -*- mode: ruby; coding: sjis -*-
# Last updated: <2016/01/10 10:16:45 +0900>
#
# 8bit PC CG Editor
#
# @version 1.0.1
# @author mieki256
#
# License: CC0 / Public Domain
#
# use:
#   * Ruby 2.0.0p647
#   * DXRuby 1.4.2
#   * chunky_png 1.3.5
#   * Windows7 x64

require 'dxruby'
require 'chunky_png'
require 'yaml'
require 'json'
require 'pp'

$version_str = "1.0.1"
$wdw_title = "8bit PC CG Editor #{$version_str}"

# ----------------------------------------
# set variable by config file

$fnt = Font.new(16, "Arial Bold")
$fntl = Font.new(24, "Arial Bold")
$scale = 2
$def_chr_set = "pet2015"
$def_pal_set = "pet2015"
$chr_idx = 16
$canvas_w = 40
$canvas_h = 25
$fg_color = [255, 255, 255, 255]
$bg_color = [255, 0, 0, 0]

# config end
# ----------------------------------------

$chr_set_idx = 0
$pal_set_idx = 0

$base_dir = "."

$res_imgs = nil
$chr_list = {}
$pal_list = {}

$canvas = nil
$brush = nil
$toolbar = nil
$paintfgbar = nil
$chrsetbar = nil
$palsetbar = nil
$popup = nil

$brush_remake = false
$framecounter = 0
$mode = :mode_pen
$paint_fg = 0x07
$current_file = ""

$cpuload_disp = false

class FileAccess
  @@json_filters = [
    ["JSON(*.json)", "*.json"],
    ["All file(*.*)", "*.*"]
  ]

  # load config file
  # @param fn [String] config file path
  def self.load_config(fn)
    return unless File.exist?(fn)

    f = open(fn)
    str = f.read()
    f.close

    cfg = YAML.load(str)

    $fnt = Font.new(cfg[:fnt_size], cfg[:fnt_name])
    $fntl = Font.new(cfg[:fntl_size], cfg[:fntl_name])
    $scale = cfg[:scale]
    $def_chr_set = cfg[:def_chr_set]
    $def_pal_set = cfg[:def_pal_set]
    $chr_idx = cfg[:chr_idx]
    $canvas_w = cfg[:canvas_width]
    $canvas_h = cfg[:canvas_height]
    $fg_color = cfg[:fg_color]
    $bg_color = cfg[:bg_color]
    $mode_shortcut_key = cfg[:shortcut]

    $mode_shortcut_key.each do |d|
      d[0] = DXRuby.const_get("K_#{d[0]}")
    end
  end

  # load resource image
  def self.load_res(src_dir)

    # load window title icon
    filepath = File.join(src_dir, "res/8bitpccgeditor_16x16.ico")
    Window.loadIcon(filepath)

    dt = [
      {
        :file => "res/toolbar.png", :rows => 11, :columns => 2,
        :names => [
          "btn_off", "btn_on",
          "new", "load", "save", "export",
          "pen", "erase", "line", "rect", "rect_fill",
          "fill", "text",
          "zoom_plus", "zoom_minus", "size_plus", "size_minus",
          "undo", "grid", "swap",
          "empty1", "empty2",
        ]
      },
      {
        :file => "res/button.png", :rows => 13, :columns => 1,
        :names => [
          "s_btn_off", "s_btn_on",
          "chk_off", "chk_on",
          "down", "up", "left", "right",
          "s_zoom_plus", "s_zoom_minus",
          "plus", "minus",
          "transcolor"
        ]
      },
      {
        :file => "res/flagbutton3.png", :rows => 5, :columns => 1,
        :names => [
          "fg_btn_off", "fg_btn_on",
          "fg_chara", "fg_fgcol", "fg_bgcol",
        ]
      },
      {
        :file => "res/guide.png", :rows => 4, :columns => 1,
        :names => [
          "guide_left_top", "guide_left_bottom",
          "guide_right_top", "guide_right_bottom"
        ]
      },
    ]

    imgs_all = {}
    dt.each do |d|
      filepath = File.join(src_dir, d[:file])
      imgs = Image.loadTiles(filepath, d[:rows], d[:columns])
      d[:names].each_with_index {|s, i| imgs_all[s] = imgs[i]}
    end
    return imgs_all
  end

  # file load, save, export
  # @param sel [Symbol] :file_(new|load|save|export)
  def self.access_file(sel)
    mes = nil
    fn = nil

    case sel
    when :file_new
      $canvas.init($canvas.w, $canvas.h, get_chr_set_name)
      $popup.set_mes("Create New Canvas. Chr set : #{get_chr_set_name}")
      $current_file = ""
      set_window_caption

    when :file_load
      fn = Window.openFilename(@@json_filters, "Load canvas data")
      if fn
        FileAccess.load_data_file(fn)
        mes = "Load"
      end

    when :file_save
      fn = FileAccess.get_save_filename
      if fn
        FileAccess.save_data_file(fn)
        mes = "Save"
      end

    when :file_save_overwrite
      if $current_file == ""
        fn = FileAccess.get_save_filename
      else
        fn = $current_file
      end
      if fn
        FileAccess.save_data_file(fn)
        mes = "Save"
      end

    when :file_export
      filters = [
        ["PNG file(*.png)", "*.png"],
        ["All file(*.*)", "*.*"]
      ]
      fn = Window.saveFilename(filters, "Export PNG")
      if fn
        fn += ".png" unless fn =~ /\.png$/i
        save_dxruby_image(fn, $canvas.canvas_img)
        mes = "Export PNG"
      end
    end

    if fn and mes
      bsname = File.basename(fn)
      $popup.set_mes("#{mes} : #{bsname}", 60)
    end
  end

  def self.load_data_file(fn)
    f = open(fn, "r")
    json = f.read
    f.close
    $canvas.load_init(json)
    $current_file = fn
    set_window_caption
  end

  def self.save_data_file(fn)
    dt = $canvas.to_json
    f = open(fn, "w")
    f.puts(dt)
    f.close
    $current_file = fn
    set_window_caption
  end

  def self.get_save_filename
    fn = Window.saveFilename(@@json_filters, "Save canvas data")
    if fn
      fn += ".json" unless fn =~ /\.json$/i
    end
    return fn
  end
end

# chr set class
class ChrSetObj
  attr_accessor :img, :dispimg, :data
  attr_accessor :w, :h, :str_w, :str_h, :celw, :celh
  attr_accessor :len, :name

  def initialize(cdir, bn)
    @name = bn
    @img = Image.load("#{cdir}/#{bn}.png")
    @dispimg = @img.clone

    f = open("#{cdir}/#{bn}.char")
    @data = f.read.split("\n")
    f.close

    @w = @img.width
    @h = @img.height
    @str_w = @data[0].length
    @str_h = @data.length
    @celw = @w / @str_w
    @celh = @h / @str_h
    @len = @str_w * @str_h

    # puts "#{bn}\t#{w}x#{h}\tstr=#{str_w}x#{str_h}\tcel=#{celw}x#{celh}"

    @chr_str = @data.join("")
  end

  def make_disp_img(fgcol, bgcol)
    @dispimg = Image.new(@w, @h)
    @h.times do |y|
      @w.times do |x|
        c = @img[x, y]
        if c == [255, 0, 0, 0]
          @dispimg[x, y] = bgcol
        elsif
          a = fgcol[0]
          r = (fgcol[1] * c[1] / 255).to_i
          g = (fgcol[2] * c[2] / 255).to_i
          b = (fgcol[3] * c[3] / 255).to_i
          @dispimg[x, y] = [a, r, g, b]
        end
      end
    end
  end

  # get characte image list
  # @param cdir [String] char dir path
  # @return [Hash] character image list
  def self.load_chr_set_imgs(cdir)
    lst = {}
    Dir.entries(cdir).each do |s|
      next if s =~ /^\.{1,2}/
      if s =~ /^(.+)\.png$/i
        cname = $1
        if File.exist?("#{cdir}/#{cname}.char")
          lst[$1] = ChrSetObj.new(cdir, cname)
        end
      end
    end
    return lst
  end

  def get_scale
    scale = 2
    scale = 1 if @w > 128 or @h > 176
    return scale
  end

  def get_chr_set_wdw_size
    scale = get_scale
    return @w * scale, @h * scale
  end

  # search chr index
  # @param str [String] character string
  # @return [Integer, nil] nil = not found, Integer = found index
  def get_chr_idx(str)
    return @chr_str.index(str)
  end
end

class PalSetObj
  attr_accessor :img, :w, :h, :name

  def initialize(cdir, bn)
    @name = bn
    @img = load_gpl_to_image("#{cdir}/#{bn}.gpl")
    @w = @img.width
    @h = @img.height
  end

  def load_gpl_to_image(fn)
    f = open(fn)
    gpl = f.read
    f.close

    @gpl_name = ""
    @gpl_columns = 16
    col_list = []
    gpl.split("\n").each do |l|
      next if l =~ /^$/
      next if l =~ /^\#/
      next if l =~ /^GIMP Palette/

      if l =~ /^Name: (.+)$/
        @gpl_name = $1
      elsif l =~ /^Columns: (\d+)/
        @gpl_columns = $1.to_i
      elsif l =~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/
        r, g, b, name = $1.to_i, $2.to_i, $3.to_i, $4
        col_list.push([r,g,b])
      end
    end

    cw = 16
    ch = (col_list.length / cw) + 1
    pw = 16
    ph = (col_list.length > 128)? 8 : 16
    w = cw * pw
    h = ch * ph
    img = Image.new(w, h, [255, 0, 0, 0])
    x, y = 0, 0
    col_list.each do |d|
      col = [255, d[0], d[1], d[2]]
      x0, y0 = x * pw, y * ph
      img.boxFill(x0, y0, x0 + pw, y0 + ph, col)
      x += 1
      if x >= cw
        x = 0
        y += 1
      end
    end

    return img
  end

  # get palette list
  # @param cdir [String] palette dir path
  # @return [Hash] palette image list
  def self.load_pal_set_imgs(cdir)
    lst = {}
    Dir.entries(cdir).each do |s|
      next if s=~ /^\.{1,2}/
      if s =~ /^(.+)\.gpl$/i
        lst[$1] = PalSetObj.new(cdir, $1)
      end
    end
    $pal_set_idx = get_pal_set_idx($def_pal_set)
    return lst
  end
end

class PopupMessage
  def initialize
    @mes = ""
    @timer = 0
  end

  def set_mes(str, tm = 120)
    @mes = str
    @timer = tm
  end

  def draw
    return if @timer <= 0
    w, h = Window.width - 64, 96
    x0 = (Window.width - w) / 2
    y0 = (Window.height - h) / 2
    Window.drawBoxFill(x0, y0, x0 + w, y0 + h, [64, 64, 64])

    fw = $fntl.getWidth(@mes)
    fh = $fntl.size
    x = x0 + (w - fw) / 2
    y = y0 + (h - fh) / 2
    Window.drawFont(x, y, @mes, $fntl, :color => C_WHITE)
    @timer -= 1
  end
end

class ButtonObj < Sprite

  attr_accessor :kind, :btn_type, :pushed

  # initialize
  # @param x [Integer] x position
  # @param y [Integer] y position
  # @param off_img [Object] Button BG off image
  # @param on_img [Object] Button BG on image
  # @param icon_img [Object] Button icon image
  # @param kind [Symbol] kind
  # @param btn_type [Symbol] button type. :normal or :radio or :toggle
  def initialize(x, y, off_img, on_img, icon_img, kind, btn_type = :noraml)
    super(x, y)
    @kind = kind
    @btn_type = btn_type
    @btn_on_img = on_img
    @btn_off_img = off_img
    @icon_img = icon_img
    @bx = 0
    @by = 0

    @pushed = false
    @selected = false
    @w = @btn_off_img.width
    @h = @btn_off_img.height
    @bx, @by = 0, 0
  end

  def set_base_pos(x, y)
    @bx, @by = x, y
  end

  def update
    @selected = false
    mx = Input.mousePosX
    my = Input.mousePosY
    case @btn_type
    when :normal
      if @pushed
        if check_hit(mx, my)
          if Input.mouseRelease?(M_LBUTTON)
            @pushed = false
            @selected = true
          else
            @pushed = true
          end
        else
          @pushed = false
        end
      else
        @pushed = true if (Input.mousePush?(M_LBUTTON) and check_hit(mx, my))
      end
    when :radio
      if Input.mousePush?(M_LBUTTON) and check_hit(mx, my)
        @pushed = true
        @selected = true
      end
    when :toggle
      if Input.mousePush?(M_LBUTTON) and check_hit(mx, my)
        @pushed = !@pushed
        @selected = true
      end
    end
  end

  def selected?
    return @selected
  end

  def check_hit(mx, my)
    x0 = @bx + self.x
    y0 = @by + self.y
    if x0 <= mx and y0 <= my and mx < x0 + @w and my < y0 + @h
      return true
    end
    return false
  end

  def draw
    if @pushed
      bimg = @btn_on_img
      dx, dy = 1, 1
    else
      bimg = @btn_off_img
      dx, dy = 0, 0
    end
    Window.draw(@bx + self.x, @by + self.y, bimg)
    Window.draw(@bx + self.x + dx, @by + self.y + dy, @icon_img)
  end
end

class Toolbar

  LAYOUT_DATA = [
    # x, y, key, value, radio
    [24 *  0, 0, "new", :file_new, :normal],
    [24 *  1, 0, "load", :file_load, :normal],
    [24 *  2, 0, "save", :file_save, :normal],
    [24 *  3, 0, "export", :file_export, :normal],
    [24 *  4 + 16, 0, "pen", :mode_pen, :radio],
    [24 *  5 + 16, 0, "erase", :mode_erase, :radio],
    [24 *  6 + 16, 0, "line", :mode_line, :radio],
    [24 *  7 + 16, 0, "rect", :mode_rect, :radio],
    [24 *  8 + 16, 0, "rect_fill", :mode_rect_fill, :radio],
    [24 *  9 + 16, 0, "fill", :mode_fill, :radio],
    [24 * 10 + 16, 0, "text", :mode_text, :radio],
    [24 *  4 + 16, 24, "swap", :swap, :normal],
    [24 *  5 + 16, 24, "grid", :grid, :normal],
    [24 *  6 + 16, 24, "zoom_plus", :zoom_plus, :normal],
    [24 *  7 + 16, 24, "zoom_minus", :zoom_minus, :normal],
    [24 *  8 + 16, 24, "size_plus", :size_plus, :normal],
    [24 *  9 + 16, 24, "size_minus", :size_minus, :normal],
    [24 * 10 + 16, 24, "undo", :mode_undo, :normal],
  ]

  def initialize(x = 0, y = 0)
    @x0 = 0
    @y0 = 0
    btn_off = $res_imgs["btn_off"]
    btn_on = $res_imgs["btn_on"]
    @celw = btn_off.width
    @celh = btn_off.height
    @w0 = 24 * 10 + 16 + @celw
    @h0 = 24 * 1 + @celh

    @buttons = []
    LAYOUT_DATA.each do |d|
      x, y, key, value, btn_type = d
      icon_img = $res_imgs[key]
      btn = ButtonObj.new(x, y, btn_off, btn_on, icon_img, value, btn_type)
      @buttons.push(btn)
    end
  end

  def set_mode(mode)
    $mode = mode
    case $mode
    when :mode_pen, :mode_erase, :mode_line
      $brush.init
      $canvas.mode_init
    when :mode_rect, :mode_rect_fill, :mode_fill
      $brush.init(false)
      $canvas.mode_init
    when :mode_text
      $chr_idx = 0
      $brush.init(false)
      $canvas.mode_init
      $popup.set_mes("click position and type keyboard")
    end
  end

  def update
    # check GUI buttons
    Sprite.update(@buttons)

    use_btn = false
    @buttons.each do |spr|
      if spr.btn_type == :radio
        if spr.selected?
          set_mode(spr.kind)
          use_btn = true
        end
      else
        next unless spr.selected?

        case spr.kind
        when :file_new, :file_load, :file_save, :file_export
          FileAccess.access_file(spr.kind)
        when :swap
          swap_color
        when :grid
          $canvas.toggle_grid
        when :zoom_plus
          $canvas.inc_scale
        when :zoom_minus
          $canvas.dec_scale
        when :size_plus
          $brush.inc_size
          $brush.init
        when :size_minus
          $brush.dec_size
          $brush.init
        when :mode_undo
          $canvas.pop_undo
        end
        use_btn = true
      end
    end

    # check shortcut key
    check_shortcut_key unless use_btn

    @buttons.each do |spr|
      if spr.btn_type == :radio
        spr.pushed = (spr.kind == $mode)? true : false
      end
    end
  end

  def check_shortcut_key
    return if $mode == :mode_text

    if Input.keyPush?(K_Z)
      $canvas.pop_undo # undo
      return
    end

    if check_push_ctrl_or_shift
      if Input.keyDown?(K_LCONTROL) or Input.keyDown?(K_RCONTROL)
        if Input.keyPush?(K_S)
          # Ctrl + S : save file overwrite
          FileAccess.access_file(:file_save_overwrite)
        end
      end
    else
      fg = false
      $mode_shortcut_key.each do |sym, value|
        if Input.keyPush?(sym)
          fg = exec_command(value)
          break if fg
        end
      end
    end
  end

  def exec_command(value)
    fg = false
    case value
    when :mode_pen, :mode_erase, :mode_line, :mode_rect, :mode_rect_fill, :mode_fill, :mode_text
      set_mode(value)
      fg = true
    when :command_dec_size
      $brush.dec_size
      $brush.init
      fg = true
    when :command_inc_size
      $brush.inc_size
      $brush.init
      fg = true
    when :command_dec_scale
      $canvas.dec_scale
      fg = true
    when :command_inc_scale
      $canvas.inc_scale
      fg = true
    when :command_toggle_grid
      $canvas.toggle_grid
      fg = true
    when :command_swap_color
      swap_color
      fg = true
    when :command_cpuload
      $cpuload_disp = !$cpuload_disp
      fg = true
    when :command_swap_paint_chr
      swap_paint_fg(0x01)
      fg = true
    when :command_swap_paint_fg
      swap_paint_fg(0x02)
      fg = true
    when :command_swap_paint_bg
      swap_paint_fg(0x04)
      fg = true
    end
    return fg
  end

  def swap_color
    $fg_color, $bg_color = $bg_color, $fg_color
    $brush_remake = true
  end

  def swap_paint_fg(msk)
    $paint_fg = PaintFlagBar.swap_paint_fg($paint_fg, msk)

  end

  def draw
    Sprite.draw(@buttons)
  end
end

class PaintFlagBar

  LAYOUT_DATA = [
    [280 - (40 * 3), 0, "fg_chara", 0x01],
    [280 - (40 * 2), 0, "fg_fgcol", 0x02],
    [280 - (40 * 1), 0, "fg_bgcol", 0x04],
  ]

  def initialize(x = 0, y = 48)
    @x0 = x
    @y0 = y
    off_img = $res_imgs["fg_btn_off"]
    on_img = $res_imgs["fg_btn_on"]
    @buttons = []
    LAYOUT_DATA.each do |d|
      x, y, key, msk = d
      x += @x0
      y += @y0
      icon_img = $res_imgs[key]
      btn = ButtonObj.new(x, y, off_img, on_img, icon_img, msk, :toggle)
      btn.pushed = true if $paint_fg & msk != 0
      @buttons.push(btn)
    end
  end

  def update
    msk = 0x01
    @buttons.each do |btn|
      btn.pushed = ($paint_fg & msk != 0)? true : false
      msk <<= 1
    end

    Sprite.update(@buttons)

    @buttons.each do |spr|
      if spr.selected?
        msk = spr.kind
        $paint_fg = PaintFlagBar.swap_paint_fg($paint_fg, msk)
      end
    end
  end

  def draw
    Sprite.draw(@buttons)
  end

  def self.swap_paint_fg(fg, msk)
    if fg & msk != 0
      fg ^= msk
    else
      fg |= msk
    end
    return fg
  end
end

class ChrSetBar

  attr_accessor :pal_bx, :pal_by

  LAYOUT_DATA = [
    [0, 0, "up", -1, :normal],
    [16, 0, "down", 1, :normal]
  ]

  def initialize(x = 0, y = 72)
    @x0, @y0 = x, y
    @x1, @y1 = @x0 + 8, @y0 + 24
    @cur_x, @cur_y = 0, 0
    @pal_bx, @pal_by = 0, 0
    @scale = 1
    @cursor_enable = false

    btn_off = $res_imgs["s_btn_off"]
    btn_on = $res_imgs["s_btn_on"]
    @buttons = []
    LAYOUT_DATA.each do |d|
      x, y, key, v, btype = d
      icon = $res_imgs[key]
      btn = ButtonObj.new(@x0 + x, @y0 + y, btn_off, btn_on, icon, v, btype)
      @buttons.push(btn)
    end
  end

  def update_chr_set_name
    Sprite.update(@buttons)
    @buttons.each do |spr|
      if spr.selected?
        clen = $chr_list.length
        $chr_set_idx = ($chr_set_idx + clen + spr.kind) % clen
        make_chr_set_image
        $brush_remake = true
      end
    end
  end

  def update_chr_set
    x0, y0 = @x1, @y1
    @cursor_enable = false

    return if $mode == :mode_text

    c = get_chr_set
    @scale = c.get_scale
    old_chr_idx = $chr_idx

    # check mouse
    aw, ah = c.get_chr_set_wdw_size
    x, y = check_mouse_in_area(x0, y0, aw, ah)
    if x != nil
      @cursor_enable = true
      cw, ch = c.celw * @scale, c.celh * @scale
      @cur_x, @cur_y = (x / cw).to_i, (y / ch).to_i
      if Input.mousePush?(M_LBUTTON)
        n = @cur_y * c.str_w + @cur_x
        $chr_idx = n if $chr_idx != n
      end
    end

    # check shortcut key
    unless check_push_ctrl_or_shift
      if Input.keyPush?(K_W)
        $chr_idx -= c.str_w
        $chr_idx += c.len if $chr_idx < 0
      elsif Input.keyPush?(K_S)
        $chr_idx += c.str_w
        $chr_idx -= c.len if $chr_idx >= c.len
      elsif Input.keyPush?(K_A)
        $chr_idx -= 1
        $chr_idx += c.len if $chr_idx < 0
      elsif Input.keyPush?(K_D)
        $chr_idx += 1
        $chr_idx -= c.len if $chr_idx >= c.len
      end
    end

    $brush_remake = true if old_chr_idx != $chr_idx
  end

  def update
    update_chr_set_name
    update_chr_set
  end

  def make_chr_set_image
    c = get_chr_set
    c.make_disp_img($fg_color, $bg_color)
    $chr_idx = 0 if $chr_idx >= c.len
  end

  def draw
    # draw chr set name
    Sprite.draw(@buttons)
    Window.drawFont(@x0 + 32 + 8, @y0, get_chr_set_name, $fnt)

    # draw chr_set image
    bx, by = @x1, @y1
    c = get_chr_set
    cw, ch = c.celw * @scale, c.celh * @scale

    Window.drawScale(bx, by, c.dispimg, @scale, @scale, 0, 0)

    if @cursor_enable
      Window.drawFont(224, @y0, "#{@cur_x},#{@cur_y}", $fnt)
      col = ($framecounter & 0x08 == 0)? [0, 255, 0] : [0, 64, 0]
      x = bx + @cur_x * cw
      y = by + @cur_y * ch
      draw_box(x - 1, y - 1, cw + 2, ch + 2, col, 1)
    end

    # draw cursor
    x = $chr_idx % c.str_w
    y = (($chr_idx - x) / c.str_w).to_i
    px = bx + x * cw - 1
    py = by + y * ch - 1
    pw, ph = cw + 2, ch + 2
    col = ($framecounter & 0x08 == 0)? [255, 0, 0] : [64, 0, 0]
    draw_box(px, py, pw, ph, col, 2)

    @pal_bx = @x0
    @pal_by = by + c.h * @scale + 8
  end

end

class PaletteSetBar

  LAYOUT_DATA = [
    [0, 0, "up", -1, :normal],
    [16, 0, "down", 1, :normal]
  ]

  def initialize
    @x0, @y0 = 0, 0
    @x1, @y1 = 0, 0

    btn_off = $res_imgs["s_btn_off"]
    btn_on = $res_imgs["s_btn_on"]
    @buttons = []
    LAYOUT_DATA.each do |d|
      x, y, key, v, btype = d
      icon = $res_imgs[key]
      btn = ButtonObj.new(@x0 + x, @y0 + y, btn_off, btn_on, icon, v, btype)
      @buttons.push(btn)
    end
  end

  def update_palette_name
    @x0, @y0 = $chrsetbar.pal_bx, $chrsetbar.pal_by
    @buttons.each { |spr| spr.set_base_pos(@x0, @y0) }
    Sprite.update(@buttons)
    @buttons.each do |spr|
      if spr.selected?
        clen = $pal_list.length
        $pal_set_idx = ($pal_set_idx + clen + spr.kind) % clen
      end
    end
  end

  def update_palette_set
    @x1 = @x0
    @y1 = @y0 + 24

    if Input.mousePush?(M_LBUTTON) or Input.mousePush?(M_RBUTTON)
      timg = $res_imgs["transcolor"]
      x, y = check_mouse_in_area(@x1, @y1, timg.width, timg.height)
      if x != nil
        # set transparent color
        ncol = [0, 0, 0, 0] # a,r,g,b
        if Input.mousePush?(M_LBUTTON)
          $fg_color = ncol
        else
          $bg_color = ncol
        end
        $brush_remake = true
      else
        p = get_pal_set
        x, y = check_mouse_in_area(@x1 + timg.width, @y1, p.w , p.h)
        if x != nil
          # set normal color
          col = p.img[x, y]
          ncol = [255, col[1], col[2], col[3]]
          if Input.mousePush?(M_LBUTTON)
            $fg_color = ncol
          else
            $bg_color = ncol
          end
          $brush_remake = true
        end
      end
    end
  end

  def update
    update_palette_name
    update_palette_set
  end

  def draw
    Sprite.draw(@buttons)
    Window.drawFont(@x0 + 32 + 8, @y0, get_pal_set_name, $fnt)

    timg = $res_imgs["transcolor"]
    Window.draw(@x1, @y1, timg)
    Window.draw(@x1 + timg.width, @y1, get_pal_set.img)
  end
end

class MapData

  attr_accessor :w, :h
  attr_accessor :data

  # init map data
  # @param w [Integer] width (character)
  # @param h [Integer] height (character)
  # @param fg [Array] foreground color [a,r,g,b]
  # @param bg [Array] background color [a,r,g,b]
  # @param cname [String] chr set name
  # @param code [Integer] chr code
  def initialize(w = 40, h = 25,
                 fg = [0,0,0,0],
                 bg = [0,0,0,0],
                 cname = $def_chr_set, code = 0)
    make_data(w, h, fg, bg, cname, code)
  end

  def self.new_load(json)
    dt = JSON.parse(json, {:symbolize_names => true})
    $chr_set_idx = get_chr_set_idx(dt[:chr_set])
    w = dt[:w]
    h = dt[:h]
    mdt = MapData.new(w, h)
    mdt.data = dt[:data]
    return mdt
  end

  # make map data
  # @param w [Integer] width (character)
  # @param h [Integer] height (character)
  # @param fg [Array] foreground color [a,r,g,b]
  # @param bg [Array] background color [a,r,g,b]
  # @param cname [String] chr set name
  # @param code [Integer] chr code
  def make_data(w, h, fg, bg, cname, code)
    @w = w
    @h = h
    @data = []
    h.times do |y|
      rows = []
      w.times do |x|
        rows.push({:fg => fg, :bg => bg, :chr_set => cname, :code => code})
      end
      @data.push(rows)
    end
    @refresh_list = []
  end

  def create_empty_image(cname)
    c = get_chr_set(cname)
    w = @w * c.celw
    h = @h * c.celh
    return Image.new(w, h, [0,0,0,0])
  end

  def create_image(cname)
    img = create_empty_image(cname)
    c = get_chr_set(cname)
    cw, ch = c.celw, c.celh
    @data.each_with_index do |rows, y|
      rows.each_with_index do |d, x|
        bimg = get_chr_img(d[:fg], d[:bg], d[:chr_set], d[:code])
        img.copyRect(x * cw, y * ch, bimg)
      end
    end
    return img
  end

  # set data
  # @param bx [Integer] x position (chr)
  # @param by [Integer] y position (chr)
  # @param mapdt [Object] Mapdata object
  # @param flg [Integer] paint flag, bit0,1,2 = chr,fg,bg
  # @param refresh [true, false] true = redraw buffer refresh , false = no refresh
  def set_data(bx, by, mapdt, flg, refresh = true)
    @refresh_list = [] if refresh
    dt = mapdt.data
    dt.each_with_index do |rows, y|
      ny = by + y
      next if ny < 0 or @h <= ny
      rows.each_with_index do |src, x|
        nx = bx + x
        next if nx < 0 or @w <= nx
        write_data(nx, ny, src, flg)
      end
    end
  end

  def write_data(nx, ny, src, flg)
    dst = @data[ny][nx]
    unless dst == src
      dst[:bg] = src[:bg] if (flg & 0x04) != 0
      dst[:fg] = src[:fg] if (flg & 0x02) != 0
      if (flg & 0x01) != 0
        dst[:chr_set] = src[:chr_set]
        dst[:code] = src[:code]
      end
      @refresh_list.push([nx, ny])
    end
  end

  # set data one character
  # @param bx [Integer] x position (chr)
  # @param by [Integer] y position (chr)
  # @param fg [Array] foreground color [a,r,g,b]
  # @param bg [Array] background color [a,r,g,b]
  # @param chr_set [String] chr set name
  # @param code [Integer] chr code
  # @param flg [Integer] paint flag, bit0,1,2 = chr,fg,bg
  # @param refresh [true, false] true = redraw buffer refresh , false = no refresh
  def set_data_one_chr(bx, by, fg, bg, chr_set, code, flg, refresh = true)
    @refresh_list = [] if refresh
    src = {:fg => fg, :bg => bg, :chr_set => chr_set, :code => code}
    write_data(bx, by, src, flg)
  end

  # set line
  # @param x0 [Integer] x start position (chr)
  # @param y0 [Integer] y start position (chr)
  # @param x1 [Integer] x end position (chr)
  # @param y1 [Integer] y end position (chr)
  # @param mapdt [Object] Mapdata object
  # @param flg [Integer] paint flag, bit0,1,2 = chr,fg,bg
  def set_line(x0, y0, x1, y1, mapdt, flg)
    @refresh_list = []
    lst = MapData.get_line_pos_list(x0, y0, x1, y1)
    ofsx = BrushObj.get_ofs(mapdt.w)
    ofsy = BrushObj.get_ofs(mapdt.h)
    lst.each do |nx, ny|
      set_data(nx - ofsx, ny - ofsy, mapdt, flg, false)
    end
  end

  # set rect
  # @param bx [Integer] x position (chr)
  # @param by [Integer] y position (chr)
  # @param w [Integer] width (chr)
  # @param h [Integer] height (chr)
  # @param fg [Array] foreground color [a,r,g,b]
  # @param bg [Array] background color [a,r,g,b]
  # @param chr_set [String] chr set name
  # @param code [Integer] chr code
  # @param flg [Integer] paint flag
  def set_rect(bx, by, w, h, fg, bg, chr_set, code, flg)
    @refresh_list = []
    src = { :fg => fg, :bg => bg, :chr_set => chr_set, :code => code }
    w.times do |x|
      nx = bx + x
      next if nx < 0 or @w <= nx
      ny = by
      write_data(nx, ny, src, flg) if 0 <= ny and ny < @h
      ny = by + h - 1
      write_data(nx, ny, src, flg) if 0 <= ny and ny < @h
    end

    h.times do |y|
      ny = by + y
      next if ny < 0 or @h <= ny
      nx = bx
      write_data(nx, ny, src, flg) if 0 <= nx and nx < @w
      nx = bx + w - 1
      write_data(nx, ny, src, flg) if 0 <= nx and nx < @w
    end
  end

  def set_rect_fill(bx, by, w, h, fg, bg, chr_set, code, flg)
    @refresh_list = []
    src = { :fg => fg, :bg => bg, :chr_set => chr_set, :code => code }
    h.times do |y|
      ny = by + y
      next if ny < 0 or @h <= ny
      w.times do |x|
        nx = bx + x
        next if nx < 0 or @w <= nx
        write_data(nx, ny, src, flg) if 0 <= ny and ny < @h
      end
    end
  end

  def get_copy_data(bx, by, w, h)
    dt = MapData.new(w, h)
    h.times do |y|
      w.times do |x|
        next if by + y >= @h
        next if bx + x >= @w
        src = @data[by + y][bx + x]
        dt.data[y][x] = Marshal.load(Marshal.dump(src))
      end
    end
    return dt
  end

  def change_image(img)
    return if @refresh_list.empty?

    @refresh_list.each do |d|
      x, y = d
      dst = @data[y][x]
      cname = dst[:chr_set]
      bimg = get_chr_img(dst[:fg], dst[:bg], cname, dst[:code])
      c = get_chr_set(cname)
      img.copyRect(x * c.celw, y * c.celh, bimg)
    end
  end

  # get character image
  # @param fg [Array] foreground color [a, r, g, b]
  # @param bg [Array] background color [a, r, g, b]
  # @param cname [String] chr set name
  # @param code [Integer] chr code
  # @return [Object] DXRuby Image
  def get_chr_img(fg, bg, cname, code)
    c = $chr_list[cname]
    bimg = Image.new(c.celw, c.celh)
    x = (code % c.str_w)
    y = (code / c.str_w).to_i
    x *= c.celw
    y *= c.celh
    bimg.copyRect(0, 0, c.img, x, y, c.celw, c.celh)
    bimg.height.times do |y|
      bimg.width.times do |x|
        col = bimg[x, y]
        if col == [255, 0, 0, 0]
          bimg[x, y] = bg
        else
          a = fg[0]
          r = (col[1] * fg[1] / 255).to_i
          g = (col[2] * fg[2] / 255).to_i
          b = (col[3] * fg[3] / 255).to_i
          bimg[x, y] = [a, r, g, b]
        end
      end
    end
    return bimg
  end

  # get line position list
  # @param x0 [Integer] line start x
  # @param y0 [Integer] line start y
  # @param x1 [Integer] line end x
  # @param y1 [Integer] line end y
  # @return [Array] position list, [[x,y],[x,y],...]
  def self.get_line_pos_list(x0, y0, x1, y1)
    lst = []

    if y0 == y1
      # horizontal line
      x0 ,x1 = x1, x0 if x0 > x1
      (x0..x1).each { |x| lst.push([x, y0]) }
      return lst
    end

    if x0 == x1
      # vertical line
      y0, y1 = y1, y0 if y0 > y1
      (y0..y1).each { |y| lst.push([x0, y]) }
      return lst
    end

    nx = x0
    ny = y0
    dx = x1 - x0
    dy = y1 - y0
    sx = (dx < 0)? -1 : 1
    sy = (dy < 0)? -1 : 1
    dx = (dx * 2).abs
    dy = (dy * 2).abs
    lst.push([nx, ny])
    if dx > dy
      f = dy - dx / 2
      while nx != x1
        if f >= 0
          ny += sy
          f -= dx
        end
        nx += sx
        f += dy
        lst.push([nx, ny])
      end
    else
      f = dx - dy / 2
      while ny != y1
        if f >= 0
          nx += sx
          f -= dy
        end
        ny += sy
        f += dx
        lst.push([nx, ny])
      end
    end
    return lst
  end

  def read_point(x, y)
    return @data[y][x]
  end

  def read_point_deep(x, y)
    return Marshal.load(Marshal.dump(@data[y][x]))
  end

  # By searching the sheet from the line and then stored in the buffer
  # @param lx [Integer] line x left
  # @param rx [Integer] line x right
  # @param y [Integer] line y
  # @param oy [Integer] parent line y
  # @param col [Hash] search color
  # @param buf [Array] buffer
  def scanline(lx, rx, y, oy, col, buf)
    while lx <= rx
      while lx < rx
        break if read_point(lx, y) == col
        lx += 1
      end

      break if read_point(lx, y) != col
      tlx = lx

      while lx <= rx
        break if read_point(lx, y) != col
        lx += 1
      end

      buf.push({ :lx => tlx, :rx => (lx - 1), :y => y, :oy => oy })
    end
  end

  # paint scanline seed fill
  # @param x [Integer] start x
  # @param y [Integer] start y
  # @param fg [Array] foreground color [a,r,g,b]
  # @param bg [Array] background color [a,r,g,b]
  # @param chr_set [String] chr set name
  # @param code [Integer] chr code
  # @param flg [Integer] paint flag
  def paint_scanlineseedfill(x, y, fg, bg, chr_set, code, flg)
    @refresh_list = []
    return if flg & 0x07 == 0

    src = { :fg => fg, :bg => bg, :chr_set => chr_set, :code => code }
    w = @data[0].length
    h = @data.length

    col = read_point_deep(x, y)
    return if col == src

    buf = []
    buf.push({ :lx => x, :rx => x, :y => y, :oy => y })

    while buf.length > 0
      d = buf.pop
      lx = d[:lx]
      rx = d[:rx]
      ly = d[:y]
      oy = d[:oy]

      lxsav = lx - 1
      rxsav = rx + 1

      next if read_point(lx, ly) != col

      while lx > 0
        break if read_point(lx - 1, ly) != col
        lx -= 1
      end

      while rx < w - 1
        break if read_point(rx + 1, ly) != col
        rx += 1
      end

      (lx..rx).each do |x|
        write_data(x, ly, src, flg)
      end

      if ly - 1 >= 0
        if ly - 1 == oy
          scanline(lx, lxsav, ly - 1, ly, col, buf)
          scanline(rxsav, rx, ly - 1, ly, col, buf)
        else
          scanline(lx, rx, ly - 1, ly, col, buf)
        end
      end

      if ly + 1 <= h - 1
        if ly + 1 == oy
          scanline(lx, lxsav, ly + 1, ly, col, buf)
          scanline(rxsav, rx, ly + 1, ly, col, buf)
        else
          scanline(lx, rx, ly + 1, ly, col, buf)
        end
      end
    end
  end

  def to_json
    dt = {
      :chr_set => get_chr_set_name,
      :w => @w,
      :h => @h,
      :data => @data
    }
    return JSON.pretty_generate(dt)
  end
end

class BrushObj

  attr_accessor :brush_data
  attr_accessor :erase_data
  attr_accessor :size
  attr_accessor :brush_img
  attr_accessor :guide_img

  def initialize
    @brush_data = nil
    @erase_data = nil
    @size = 1
    @w, @h = 0, 0
    @brush_img = nil
    @guide_img = nil
    init
  end

  # init brush data and brush image
  def init(size_enable = true)
    unless size_enable
      @size = 1
    end
    @w, @h = @size, @size

    cname = get_chr_set_name
    @brush_data = MapData.new(@w, @h, $fg_color, $bg_color, cname, $chr_idx)
    @erase_data = MapData.new(@w, @h, [0,0,0,0], [0,0,0,0], $def_chr_set, 0)
    @brush_img = @brush_data.create_image(cname)
    @guide_img = make_guide_img(@brush_img.width, @brush_img.height)
  end

  # make brush guide image
  # @param w [Integer] width (pixel)
  # @param h [Integer] height (pixel)
  def make_guide_img(w, h)
    gw, gh = 4, 4
    img = Image.new(w, h)
    img.copyRect(0, 0, $res_imgs["guide_left_top"])
    img.copyRect(img.width - gw, 0, $res_imgs["guide_right_top"])
    img.copyRect(0, img.height - gh, $res_imgs["guide_left_bottom"])
    img.copyRect(img.width - gw, img.height - gh, $res_imgs["guide_right_bottom"])
    return img
  end

  def set_data(mapdt)
    if mapdt.w == 1 and mapdt.h == 1
      @size = 1
      src = mapdt.data[0][0]
      $fg_color = Marshal.load(Marshal.dump(src[:fg]))
      $bg_color = Marshal.load(Marshal.dump(src[:bg]))
      $chr_set_idx = get_chr_set_idx(src[:chr_set])
      $chr_idx = src[:code]
      c = get_chr_set
      c.make_disp_img($fg_color, $bg_color)
      init
    else
      @w, @h = mapdt.w, mapdt.h
      @size = @w if @w == @h
      @brush_data = mapdt
      @brush_img = @brush_data.create_image(get_chr_set_name)
      @erase_data = MapData.new(@w, @h, [0,0,0,0], [0,0,0,0], $def_chr_set, 0)
      @guide_img = make_guide_img(@brush_img.width, @brush_img.height)
    end
  end

  def size_x
    return @brush_data.w
  end

  def size_y
    return @brush_data.h
  end

  # brush size increment
  def inc_size
    @size += 1
    init
  end

  # brush size decrement
  def dec_size
    return if @size <= 1
    @size -= 1
    init
  end

  # draw brush
  def draw(px, py, scale, mode, count)
    if mode == :mode_erase
      # erase mode
      if count & 0x08 == 0
        Window.drawScale(px, py, @guide_img, scale, scale, 0, 0)
      end
    else
      # pen mode
      bimg = (count & 0x08 == 0)? @brush_img : @guide_img
      Window.drawScale(px, py, bimg, scale, scale, 0, 0)
    end
  end

  def draw_select_box(x0, y0, x1, y1, scale, count)
    if count & 0x08 == 0
      x1, x0 = x0, x1 if x0 > x1
      y1, y0 = y0, y1 if y0 > y1
      gimg = $res_imgs["guide_left_top"]
      w, h = gimg.width * scale, gimg.height * scale
      [
        [x0, y0, "guide_left_top"],
        [x1 - w, y0, "guide_right_top"],
        [x0, y1 - h, "guide_left_bottom"],
        [x1 - w, y1 - h, "guide_right_bottom"],
      ].each do |x, y, k|
        Window.drawScale(x, y, $res_imgs[k], scale, scale, 0, 0)
      end
    else
      Window.drawBoxFill(x0, y0, x1, y1, [128, 255, 0, 0])
    end
  end

  def draw_rect(x0, y0, x1, y1, bx, by, scale, count, fill = false)
    c = get_chr_set
    cw = c.celw * scale
    ch = c.celh * scale
    x1, x0 = x0, x1 if x0 > x1
    y1, y0 = y0, y1 if y0 > y1

    if count & 0x10 == 0
      if fill
        (y0..y1).each do |y|
          (x0..x1).each do |x|
            px = bx + x * cw
            py = by + y * ch
            Window.drawScale(px, py, @brush_img, scale, scale, 0, 0)
          end
        end
      else
        px0 = bx + x0 * cw
        py0 = by + y0 * ch
        px1 = bx + x1 * cw
        py1 = by + y1 * ch

        (x0..x1).each do |x|
          px = bx + x * cw
          Window.drawScale(px, py0, @brush_img, scale, scale, 0, 0)
          Window.drawScale(px, py1, @brush_img, scale, scale, 0, 0)
        end

        (y0..y1).each do |y|
          py = by + y * ch
          Window.drawScale(px0, py, @brush_img, scale, scale, 0, 0)
          Window.drawScale(px1, py, @brush_img, scale, scale, 0, 0)
        end
      end
    else
      gimg = $res_imgs["guide_left_top"]
      w, h = gimg.width * scale, gimg.height * scale
      px0 = bx + x0 * cw
      py0 = by + y0 * ch
      px1 = bx + (x1 + 1) * cw - w
      py1 = by + (y1 + 1) * ch - h
      [
        [px0, py0, "guide_left_top"],
        [px1, py0, "guide_right_top"],
        [px0, py1, "guide_left_bottom"],
        [px1, py1, "guide_right_bottom"],
      ].each do |x, y, k|
        Window.drawScale(x, y, $res_imgs[k], scale, scale, 0, 0)
      end
    end
  end

  def draw_line(x0, y0, x1, y1, bx, by, scale, count)
    if count & 0x08 == 0
      c = get_chr_set
      cw = c.celw * scale
      ch = c.celh * scale
      lst = MapData.get_line_pos_list(x0, y0, x1, y1)
      ofsx = BrushObj.get_ofs(@w)
      ofsy = BrushObj.get_ofs(@h)
      lst.each do |x, y|
        px = bx + (x - ofsx) * cw
        py = by + (y - ofsy) * ch
        Window.drawScale(px, py, @brush_img, scale, scale, 0, 0)
      end
    end
  end

  def self.get_ofs(size)
    return 0 if size <= 2
    return ((size - 1) / 2).to_i
  end
end

class CanvasObj

  attr_accessor :w, :h
  attr_accessor :img_w
  attr_accessor :img_h
  attr_accessor :data
  attr_accessor :canvas_img
  attr_accessor :canvas_x
  attr_accessor :canvas_y
  attr_accessor :scale

  SCALE_MAX = 3

  # initialize
  # @param w [Integer] width (character)
  # @param h [Integer] height (character)
  # @param def_chr_set [String] chr set name
  # @param scale [Integer] display scale
  def initialize(w = 40, h = 25, def_chr_set = $def_chr_set, scale = 2)
    @scale = scale
    @canvas_x = 272
    @canvas_y = 0
    @draw_cursor = false
    @draw_grid = false
    @copy_start = false
    @btn_push_start = false
    @undo_buf = []
    @cx0 = 0
    @cy0 = 0
    @cx1 = 0
    @cy1 = 0
    init(w, h, def_chr_set)
    @keyinput = KeyInputObj.new
  end

  def mode_init
    @copy_start = false
    @btn_push_start = false
  end

  def init(w, h, def_chr_set = $def_chr_set)
    @w, @h = w, h
    @data = MapData.new(w, h, [0,0,0,0], [0,0,0,0], def_chr_set, 0)
    init_image(def_chr_set)
  end

  def init_image(chr_set_name, redraw = false)
    if redraw
      @canvas_img = @data.create_image(chr_set_name)
    else
      @canvas_img = @data.create_empty_image(chr_set_name)
    end
    @img_w = @canvas_img.width
    @img_h = @canvas_img.height
    @bgimg = make_bg_image(@img_w, @img_h)
    @grid_img = make_grid_image(@img_w, @img_h)
  end

  def load_init(json)
    mdt = MapData.new_load(json)
    @w, @h = mdt.w, mdt.h
    @data = mdt
    init_image(get_chr_set_name, true)
  end

  def to_json
    return @data.to_json
  end

  # make checkered pattern image
  # @param w [Integer] width (pixel)
  # @param h [Integer] height (pixel)
  # @return [Object] DXRuby Image
  def make_bg_image(w, h)
    bgimg = Image.new(w, h, C_WHITE)
    c0 = [224, 224, 224]
    dw = 4
    d = dw
    dws = dw - 1
    0.step(h-1, dw) do |y|
      0.step(w-1, dw * 2) do |x|
        bgimg.boxFill(x + d, y, x + d + dws, y + dws, c0)
      end
      d = (d == dw)? 0 : dw
    end
    return bgimg
  end

  # make checkered pattern image
  # @param w [Integer] width (pixel)
  # @param h [Integer] height (pixel)
  # @param col [Array] color [a,r,g,b]
  # @return [Object] DXRuby Image
  def make_grid_image(w, h, col = [128, 200, 0, 128])
    c = get_chr_set
    cw, ch = c.celw, c.celh
    img = Image.new(w, h, [0,0,0,0])
    x = 0
    while x < w
      img.line(x, 0, x, h - 1, col)
      x += cw
    end
    y = 0
    while y < h
      img.line(0, y, w - 1, y, col)
      y += ch
    end
    return img
  end

  def push_undo
    @undo_buf.push(Marshal.load(Marshal.dump(@data)))
  end

  def pop_undo
    return if @undo_buf.length <= 0
    @data = @undo_buf.pop
    init_image(get_chr_set_name, true)
  end

  def set_pos(x, y)
    @canvas_x, @Canvas_y = x, y
  end

  def inc_scale
    @scale += 1 if @scale < SCALE_MAX
    set_window_caption
  end

  def dec_scale
    @scale -= 1 if @scale > 1
    set_window_caption
  end

  def toggle_grid
    @draw_grid = !(@draw_grid)
    @grid_img = make_grid_image(@img_w, @img_h) if @draw_grid
  end

  def get_draw_size(scale = nil)
    scale = @scale unless scale
    w = @canvas_img.width * scale
    h = @canvas_img.height * scale
    return w, h
  end

  def update
    @draw_cursor = false
    x0, y0 = @canvas_x, @canvas_y
    aw = @canvas_img.width * @scale
    ah = @canvas_img.height * @scale

    x, y = check_mouse_in_area(x0, y0, aw, ah)
    if x!= nil
      @draw_cursor = true
      c = get_chr_set
      cw = c.celw * @scale
      ch = c.celh * @scale
      dx = (x / cw).to_i
      dy = (y / ch).to_i

      check_copy(dx, dy, x0, y0, cw, ch)

      unless @copy_start
        # normal mode (not copy mode)
        case $mode
        when :mode_pen
          check_mode_pen(dx, dy, x0, y0, cw, ch)
        when :mode_erase
          check_mode_pen(dx, dy, x0, y0, cw, ch, true)
        when :mode_rect, :mode_rect_fill, :mode_line
          check_mode_rect(dx, dy, x0, y0, cw, ch)
        when :mode_fill
          check_mode_fill(dx, dy, x0, y0, cw, ch)
        when :mode_text
          check_mode_text(dx, dy, x0, y0, cw, ch)
        end
      end
    end
  end

  def check_copy(x, y, x0, y0, cw, ch)
    unless @copy_start
      if Input.mousePush?(M_RBUTTON)
        @sel_x0, @sel_y0 = x, y
        @sel_x1, @sel_y1 = x, y
        @copy_start = true
      end
    else
      @sel_x1 = x
      @sel_y1 = y
      if Input.mouseRelease?(M_RBUTTON)
        @copy_start = false
        sort_sel_box
        w = (@sel_x1 - @sel_x0) + 1
        h = (@sel_y1 - @sel_y0) + 1
        $brush.set_data(@data.get_copy_data(@sel_x0, @sel_y0, w, h))
      else
        unless Input.mouseDown?(M_RBUTTON)
          @sel_x0, @sel_y0 = x, y
          @sel_x1, @sel_y1 = x, y
          @copy_start = false
        end
      end
    end

    if @copy_start
      @cx0 = x0 + @sel_x0 * cw
      @cy0 = y0 + @sel_y0 * ch
      @cx1 = x0 + @sel_x1 * cw
      @cy1 = y0 + @sel_y1 * ch
      @cx1, @cx0 = @cx0, @cx1 if @cx0 > @cx1
      @cy1, @cy0 = @cy0, @cy1 if @cy0 > @cy1
      @cx1 += cw
      @cy1 += ch
    end
  end

  def check_mode_rect(x, y, x0, y0, cw, ch)
    unless @btn_push_start
      if Input.mousePush?(M_LBUTTON)
        @sel_x0, @sel_y0 = x, y
        @sel_x1, @sel_y1 = x, y
        @btn_push_start = true
      end
    else
      @sel_x1 = x
      @sel_y1 = y
      if Input.mouseRelease?(M_LBUTTON)
        @btn_push_start = false
        push_undo
        case $mode
        when :mode_line
          @data.set_line(@sel_x0, @sel_y0, @sel_x1, @sel_y1,
                         $brush.brush_data, $paint_fg)
        when :mode_rect
          sort_sel_box
          w = (@sel_x1 - @sel_x0) + 1
          h = (@sel_y1 - @sel_y0) + 1
          @data.set_rect(@sel_x0, @sel_y0, w, h,
                         $fg_color, $bg_color, get_chr_set_name, $chr_idx,
                         $paint_fg)
        when :mode_rect_fill
          sort_sel_box
          w = (@sel_x1 - @sel_x0) + 1
          h = (@sel_y1 - @sel_y0) + 1
          @data.set_rect_fill(@sel_x0, @sel_y0, w, h,
                              $fg_color, $bg_color, get_chr_set_name, $chr_idx,
                              $paint_fg)
        end
        @data.change_image(@canvas_img)
      else
        unless Input.mouseDown?(M_LBUTTON)
          @sel_x0, @sel_y0 = x, y
          @sel_x1, @sel_y1 = x, y
          @btn_push_start = false
        end
      end
    end

    unless @btn_push_start
      if $mode == :mode_line
        ofsx = BrushObj.get_ofs($brush.size_x)
        ofsy = BrushObj.get_ofs($brush.size_y)
        @cx0 = x0 + (x - ofsx) * cw
        @cy0 = y0 + (y - ofsy) * ch
      else
        @cx0 = x0 + x * cw
        @cy0 = y0 + y * ch
      end
    else
      @cx0, @cy0 = @sel_x0, @sel_y0
      @cx1, @cy1 = @sel_x1, @sel_y1
    end
  end

  def sort_sel_box
    @sel_x1, @sel_x0 = @sel_x0, @sel_x1 if @sel_x0 > @sel_x1
    @sel_y1, @sel_y0 = @sel_y0, @sel_y1 if @sel_y0 > @sel_y1
  end

  def set_data(bx, by, brush_dt, fg)
    @data.set_data(bx, by, brush_dt, fg)
    @data.change_image(@canvas_img)
  end

  def check_mode_pen(x, y, x0, y0, cw, ch, erase = false)
    draw_fg = false
    unless @btn_push_start
      if Input.mousePush?(M_LBUTTON)
        @sel_x0, @sel_y0 = x, y
        @btn_push_start = true
        draw_fg = true
        push_undo
      end
    else
      if Input.mouseDown?(M_LBUTTON)
        draw_fg = true
      else
        @btn_push_start = false
      end
    end

    if draw_fg
      unless erase
        @data.set_line(@sel_x0, @sel_y0, x, y,
                       $brush.brush_data, $paint_fg)
      else
        @data.set_line(@sel_x0, @sel_y0, x, y,
                       $brush.erase_data, 0x07)
      end
      @data.change_image(@canvas_img)
    end

    @sel_x0 = x
    @sel_y0 = y
    ofsx = BrushObj.get_ofs($brush.size_x)
    ofsy = BrushObj.get_ofs($brush.size_y)
    @cx0 = x0 + (x - ofsx) * cw
    @cy0 = y0 + (y - ofsy) * ch
  end

  def check_mode_fill(x, y, x0, y0, cw, ch)
    if Input.mousePush?(M_LBUTTON)
      push_undo
      @data.paint_scanlineseedfill(x, y,
                                   $fg_color, $bg_color,
                                   get_chr_set_name, $chr_idx, $paint_fg)
      @data.change_image(@canvas_img)
    end
    @cx0 = x0 + x * cw
    @cy0 = y0 + y * ch
  end

  def check_mode_text(x, y, x0, y0, cw, ch)
    if Input.mousePush?(M_LBUTTON)
      @sel_x0, @sel_y0 = x, y
      @sel_x1, @sel_y1 = x, y
      @btn_push_start = true
      push_undo
    end

    if @btn_push_start
      @keyinput.update
      if @keyinput.new_chr != ""
        # type chr
        c = get_chr_set
        code = c.get_chr_idx(@keyinput.new_chr)
        if code != nil
          @data.set_data_one_chr(@sel_x0, @sel_y0,
                                 $fg_color, $bg_color,
                                 get_chr_set_name, code, $paint_fg)
          @data.change_image(@canvas_img)
          move_text_cursor(1, 0)
        end
      elsif @keyinput.backspace_pushed
        move_text_cursor(-1, 0)
        @data.set_data_one_chr(@sel_x0, @sel_y0,
                               $fg_color, $bg_color,
                               get_chr_set_name, 0x00, $paint_fg)
        @data.change_image(@canvas_img)
      else
        if Input.keyPush?(K_RIGHT)
          move_text_cursor(1, 0)
        elsif Input.keyPush?(K_LEFT)
          move_text_cursor(-1, 0)
        elsif Input.keyPush?(K_DOWN)
          move_text_cursor(0, 1)
        elsif Input.keyPush?(K_UP)
          move_text_cursor(0, -1)
        elsif Input.keyPush?(K_RETURN)
          @sel_x0 = @sel_x1
          move_text_cursor(0, 1)
        end
      end
    end

    unless @btn_push_start
      @cx0 = x0 + x * cw
      @cy0 = y0 + y * ch
    else
      @cx0 = x0 + @sel_x0 * cw
      @cy0 = y0 + @sel_y0 * ch
    end
  end

  def move_text_cursor(dx, dy)
    if dx > 0
      @sel_x0 += 1
      if @sel_x0 >= @data.w
        @sel_x0 = 0
        @sel_y0 += 1
        @sel_y0 = 0 if @sel_y0 >= @data.h
      end
    elsif dx < 0
      @sel_x0 -= 1
      if @sel_x0 < 0
        @sel_x0 = @data.w - 1
        @sel_y0 -= 1
        @sel_y0 = @data.h - 1 if @sel_y0 < 0
      end
    elsif dy > 0
      @sel_y0 += 1
      @sel_y0 = 0 if @sel_y0 >= @data.h
    elsif dy < 0
      @sel_y0 -= 1
      @sel_y0 = @data.h - 1 if @sel_y0 < 0
    end
  end

  def draw
    x0, y0 = @canvas_x, @canvas_y
    cnt = $framecounter
    Window.drawScale(x0, y0, @bgimg, @scale, @scale, 0, 0)
    Window.drawScale(x0, y0, @canvas_img, @scale, @scale, 0, 0)

    if @draw_cursor
      if @copy_start
        $brush.draw_select_box(@cx0, @cy0, @cx1, @cy1, @scale, cnt)
      elsif !@btn_push_start
        $brush.draw(@cx0, @cy0, @scale, $mode, cnt)
      else
        case $mode
        when :mode_pen, :mode_erase, :mode_fill
          $brush.draw(@cx0, @cy0, @scale, $mode, cnt)
        when :mode_rect
          $brush.draw_rect(@cx0, @cy0, @cx1, @cy1, x0, y0, @scale, cnt, false)
        when :mode_rect_fill
          $brush.draw_rect(@cx0, @cy0, @cx1, @cy1, x0, y0, @scale, cnt, true)
        when :mode_line
          $brush.draw_line(@cx0, @cy0, @cx1, @cy1, x0, y0, @scale, cnt)
        when :mode_text
          $brush.draw(@cx0, @cy0, @scale, $mode, cnt)
        end
      end
    end

    Window.drawScale(x0, y0, @grid_img, @scale, @scale, 0, 0) if @draw_grid
  end

end

class KeyInputObj

  attr_accessor :new_chr
  attr_accessor :backspace_pushed

  def initialize
    @new_chr = ""
    @backspace_pushed = false

    # make key list
    @keylist = []
    str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    str.split("").each do |c|
      c0 = ""
      c1 = ""
      if 65 <= c.ord and c.ord <= 90
        c0 = c.downcase # a-z
        c1 = c # A-Z
      else
        c0 = c # 0-9
        c1 = (c.ord - 0x10).chr # symbol
      end
      @keylist.push([DXRuby.const_get("K_#{c}"), c0, c1])
    end

    [
      [K_MINUS, "-", "="],
      [K_LBRACKET, "[", "{"],
      [K_RBRACKET, "]", "}"],
      [K_SEMICOLON, ";", "+"],
      [K_COLON, ":", "*"],
      [K_COMMA, ",", "<"],
      [K_PERIOD, ".", ">"],
      [K_SLASH, "/", "?"],
      [K_SPACE, " ", " "],
      [K_PREVTRACK, "^", "~"],
      [K_AT, "@", "`"],
      [K_YEN, "\\", "|"],
      [K_BACKSLASH, "_", "_"],
    ].each do |sym, c0, c1|
      @keylist.push([sym, c0, c1])
    end
  end

  # check shift key down
  # @return [true, false] true = Shift key down, false = not down
  def shift_downed?
    return (Input.keyDown?(K_LSHIFT) or Input.keyDown?(K_RSHIFT))
  end

  def update
    @new_chr = ""
    @keylist.each do |sym, c0, c1|
      if Input.keyPush?(sym)
        @new_chr = (shift_downed?)? c1 : c0
      end
    end

    @backspace_pushed = (Input.keyPush?(K_BACKSPACE))? true : false
  end
end

# draw box
# @param x [Integer] x
# @param y [Integer] y
# @param w [Integer] width
# @param h [Integer] height
# @param col [Array] color [a, r, g, b]
# @param border_w [Integer] border width
def draw_box(x, y, w, h, col, border_w = 1)
  w -= 1
  h -= 1
  border_w.times do |i|
    Window.drawLine(x, y, x + w, y, col)
    Window.drawLine(x, y, x, y + h, col)
    Window.drawLine(x + w, y, x + w, y + h, col)
    Window.drawLine(x, y + h, x+ w, y + h, col)
    x -= 1
    y -= 1
    w += 2
    h += 2
  end
end

# check mouse position in xxxxx
# @param x [Integer] area left
# @param y [Integer] area top
# @param w [Integer] area width
# @param h [Integer] area height
# @return [Array] [nil, nil] is not hit, [x, y] is hit
def check_mouse_in_area(x, y, w, h)
  mx = Input.mousePosX
  my = Input.mousePosY
  if x <= mx and mx < x + w and y <= my and my < y + h
    return (mx - x), (my - y)
  end
  return nil, nil
end

def check_button_area(layout_data, x0, y0, w0, h0)
  sel = nil
  x, y = check_mouse_in_area(x0, y0, w0, h0)
  if x != nil and Input.mousePush?(M_LBUTTON)
    layout_data.each do |d|
      px, py = d[0], d[1]
      key, value = d[2], d[3]
      img = $res_imgs[key]
      pw, ph = img.width, img.height
      if px <= x and x < px + pw and py <= y and y < py + pw
        sel = value
        break
      end
    end
  end
  return sel
end

def get_chr_set_idx(cname)
  idx = $chr_list.keys.index(cname)
  return (idx != nil)? idx : 0
end

def get_chr_set_name
  return $chr_list.keys[$chr_set_idx]
end

def get_chr_set(cname = nil)
  return $chr_list[((cname != nil)? cname : get_chr_set_name)]
end

def get_pal_set_idx(pname)
  idx = $pal_list.keys.index(pname)
  return (idx != nil)? idx : 0
end

def get_pal_set_name
  return $pal_list.keys[$pal_set_idx]
end

def get_pal_set
  return $pal_list[get_pal_set_name]
end

def check_push_ctrl_or_shift
  return true if Input.keyDown?(K_LCONTROL) or Input.keyDown?(K_RCONTROL)
  return true if Input.keyDown?(K_LSHIFT) or Input.keyDown?(K_RSHIFT)
  return false
end

# set window size
def set_window_size
  chrw, chrh = 0, 0
  $chr_list.each_value do |v|
    w, h = v.get_chr_set_wdw_size
    chrw = w if chrw < w
    chrh = h if chrh < h
  end

  palw, palh = 0, 0
  $pal_list.each_value do |v|
    palw = v.w if palw < v.w
    palh = v.h if palh < v.h
  end

  x = 8 + 16 * 16 + 8 + 16
  x = 272 if x < 272
  y = 0
  cw, ch = $canvas.get_draw_size(3)
  w = x + cw
  h = y + ch
  th = 80 + chrh + 8 + 32 + 16 + palh + 8
  h = th if h < th
  Window.resize(w, h)

  $canvas.set_pos(x, y)

  set_window_caption
end

def set_window_caption
  wdwsize = "Wdw:#{Window.width}x#{Window.height}"
  csize = "Canvas:#{$canvas.w}x#{$canvas.h}"
  sc = "Scale:#{$canvas.scale}"
  bsname = File.basename($current_file)
  bsstr = (bsname == "")? "" : "#{bsname} - "
  Window.caption = "#{bsstr}#{$wdw_title} (#{sc} #{csize} #{wdwsize})"
end

# save 32bit png image from DXRuby Image
# @param fn [String] filename
# @param img [Object] DXRuby Image
def save_dxruby_image(fn, img)
  w = img.width
  h = img.height
  png = ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
  h.times do |y|
    w.times do |x|
      a, r, g, b = img[x, y]
      png[x, y] = ChunkyPNG::Color.rgba(r, g, b, a)
    end
  end
  png.save(fn, :fast_rgba)
end


def draw_cpuload_bar
  w = (Window.width * Window.getLoad / 100).to_i
  Window.drawBoxFill(0, Window.height - 4, w, Window.height, C_RED)
end

# ============================================================
# main

# support OCRA
base_file = ENV['OCRA_EXECUTABLE'] || $0
$base_dir = File.expand_path(File.dirname(base_file))
# puts $base_dir

# set scale filter
Window.minFilter = TEXF_POINT
Window.magFilter = TEXF_POINT

# key repeat on
Input.set_repeat(45, 5)

# load config
FileAccess.load_config(File.join($base_dir, "config.yaml"))

# load images
$res_imgs = FileAccess.load_res($base_dir)
$chr_list = ChrSetObj.load_chr_set_imgs(File.join($base_dir, "char"))
$pal_list = PalSetObj.load_pal_set_imgs(File.join($base_dir, "pal"))

$chr_set_idx = get_chr_set_idx($def_chr_set)
$pal_set_idx = get_pal_set_idx($def_pal_set)

$canvas = CanvasObj.new($canvas_w, $canvas_h, get_chr_set_name, $scale)
$brush = BrushObj.new()
set_window_size

$toolbar = Toolbar.new
$paintfgbar = PaintFlagBar.new
$chrsetbar = ChrSetBar.new
$palsetbar = PaletteSetBar.new
$popup = PopupMessage.new

Window.loop do
  break if Input.keyPush?(K_ESCAPE)

  $brush_remake = false

  $toolbar.update
  $paintfgbar.update
  $chrsetbar.update
  $palsetbar.update

  if $brush_remake
    c = get_chr_set
    c.make_disp_img($fg_color, $bg_color)
    $brush.init

    if $mode == :mode_erase or $mode == :mode_text
      $toolbar.set_mode(:mode_pen)
    end
  end

  $canvas.update

  $toolbar.draw
  $paintfgbar.draw
  $chrsetbar.draw
  $palsetbar.draw
  $canvas.draw

  draw_cpuload_bar if $cpuload_disp

  $popup.draw

  $framecounter += 1
end
