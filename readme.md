8bit PC CG Editor
=================

ASCII/ANSI art tool, similar to the screen of 8bit PC. It is a Windows-only application. Free is the software.

8bit PCっぽい画面(ASCIIアート？)を作れるエディタです。Windows専用のフリーソフトです。

## ScreenShot

![ScreenShot1](screenshot/8bitpccgeditor_ss1.png?raw=true )

![ScreenShot2](screenshot/8bitpccgeditor_ss2.png?raw=true )

## Download

[Releases · mieki256/8bitpccgeditor](https://github.com/mieki256/8bitpccgeditor/releases/ )

## Usage - 使い方

Run 8bitpccgeditor.exe or ruby.exe 8bitpccgeditor.rb.

8bitpccgeditor.exe か ruby.exe 8bitpccgeditor.rb を実行。

## Install - インストール方法
Unzip the zip.You put in any folder. But, it does not work when put under the Japanese name folder.

Uninstall, please delete each folder where you unzipped. Registry does not use.

zipを解凍して任意のフォルダに置いてください。ただし、日本語名のフォルダの下に置くと動作しません。

アンインストールは、解凍したフォルダごと削除してください。レジストリは使ってません。

## Operation - 操作方法

### Canvas - キャンバス

* LMB(Left mouse button) : draw (描画)
* RMB(Right mouse button) : copy character. (キャラコピー)
    * If drag you can copy multiple characters. (右ボタンドラッグで複数のキャラをコピーできます)

### Select character - キャラ選択

* LMB : select character (キャラ選択)

### Select color - 色選択

* LMB : select foregorund color (前景色選択)
* RMB : select background color (背景色選択)

### Toolbar - ツールバー種類

* New (新規作成)
* Load (データロード)
* Save (データ保存)
* Eport PNG (PNG画像でエクスポート)
* Brsuh (ブラシ)
* Erase (消しゴム)
* Line (直線描画)
* Rectangle (矩形)
* Fill Rectangle (矩形塗りつぶし)
* Fill (バケツツール)
* Text (テキスト入力)

- - - - 

* Swap foreground/background color (前景色と背景色の交換)
* Grid on/off (グリッド表示切替)
* Zoom + (キャンバス拡大)
* Zoom - (キャンバス縮小)
* Brush size + (ブラシサイズを大きくする)
* Brush size - (ブラシサイズを小さくする)
* Undo (取り消し)

- - - - 

* Chr : Character draw on/off (キャラクタ書き込み on/off)
* Fg : Foreground color draw on/off (前景色書き込み on/off)
* Bg : Background color draw on/off (背景色書き込み on/off)

## Keyboard Shortcuts - ショートカットキー一覧

* Z : Undo (取り消し)
* Ctrl+S : Save (保存)
* WASD : chr cursor move (キャラ選択カーソルの移動)
* X or @ : swap foreground/background color (前景色と背景色の交換)
* G : grid on/off (グリッド表示切替)
* 1 : Chr draw on/off (キャラ描画 on/off)
* 2 : Fg draw on/off (前景色描画 on/off)
* 3 : Bg draw on/off (背景色描画 on/off)
* Q : brush size - (ブラシサイズを小さくする)
* E : brush size + (ブラシサイズを大きくする)
* 4 : zoom - (キャンバス縮小)
* 5 : zoom + (キャンバス拡大)
* B : Brush (ブラシ)
* C : Erase (消しゴム)
* L : Line (直線描画)
* R : Rectangle (矩形)
* I : Fill Rectangle (矩形塗りつぶし)
* F : Fill (バケツツール)
* T : Text (テキスト入力)
* 9 : CPU load display on/off (CPU使用率表示 on/off)

## Dependencies - 使用言語・依存ライブラリ

* Ruby 2.0.0p647 : [RubyInstaller for Windows](http://rubyinstaller.org/ )
* DXRuby 1.4.2 : [Project DXRuby](http://dxruby.osdn.jp/ )
* chunky_png 1.3.5 : [chunky_png - RubyGems.org](https://rubygems.org/gems/chunky_png/versions/1.3.5 )


## License

CC0 / Public domain.

exeファイルだけは、Ruby, DXRuby, chunky_png のライセンスに従います。

only exe file is a different license. Because it contains the binary of Ruby and DXRuby and chunky_png.
(Ruby is Ruby license.DXRuby the zlib / libpng license. Chunky_png the MIT license.)

## Append data - データの追加について

キャラクタセット画像は、[EDSCII] に同梱されてる画像と互換性があります。[EDSCII]をダウンロードして解凍後、charフォルダ内の \*.png と \*.char を、charフォルダにコピーすれば、利用できるキャラクタセットを増やせます。

MZ-700のキャラクタセット画像も作ってみました。[mieki256's diary - 2015/12/04](http://blawat2015.no-ip.com/~mieki256/diary/20151204.html#201512041 )から入手できます。
 
[EDSCII]:http://vectorpoem.com/edscii/

