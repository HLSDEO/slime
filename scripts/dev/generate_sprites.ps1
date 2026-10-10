# Generates character sprite sheets (6 frames: down1,down2,left1,left2,up1,up2) as 16px art scaled 2x.
# Re-run: powershell -ExecutionPolicy Bypass -File scripts\dev\generate_sprites.ps1
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$outDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "assets\generated"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$pal = @{
  'o' = @(20,20,30)     # outline
  'e' = @(10,10,15)     # eyes
  'w' = @(255,255,255)  # highlight/white
  's' = @(240,200,170)  # skin
  'k' = @(0,0,0)
}
function C([int]$r,[int]$g,[int]$b,[int]$a=255){ return [System.Drawing.Color]::FromArgb($a,$r,$g,$b) }

# creature palettes: body b, dark d, accent a2
function Hex([string]$h){ return C ([convert]::ToInt32($h.Substring(0,2),16)) ([convert]::ToInt32($h.Substring(2,2),16)) ([convert]::ToInt32($h.Substring(4,2),16)) }
function Render([string]$name,[string[]]$down,[string[]]$side,[string]$bgr,[string]$dkr,[string]$ac2,[string]$skin='',[string]$hair=''){
  $colors = @{}
  foreach($k in $pal.Keys){ $colors[$k] = C $pal[$k][0] $pal[$k][1] $pal[$k][2] }
  $colors['b'] = Hex $bgr
  $colors['d'] = Hex $dkr
  $colors['a'] = Hex $ac2
  $colors['t'] = $colors['b']
  if($skin){ $colors['s'] = Hex $skin }
  if($hair){ $colors['h'] = Hex $hair }
  $up = @($down | ForEach-Object { $_ -replace 'e','b' })
  $fd = @(Normalize $down); $fs = @(Normalize $side); $fu = @(Normalize $up)
  $frames = @($fd, (ShiftDown $fd), $fs, (ShiftDown $fs), $fu, (ShiftDown $fu))
  $bmp = New-Object System.Drawing.Bitmap (96*2), (16*2)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'NearestNeighbor'
  for($f=0; $f -lt 6; $f++){
    $rows = $frames[$f]
    for($y=0;$y -lt 16;$y++){
      $row = $rows[$y]
      for($x=0;$x -lt 16;$x++){
        $ch = $row[$x]
        if($ch -eq '.' -or -not $colors.ContainsKey([string]$ch)){ continue }
        $col = $colors[[string]$ch]
        $br = New-Object System.Drawing.SolidBrush $col
        $g.FillRectangle($br, ($f*16+$x)*2, $y*2, 2, 2)
        $br.Dispose()
      }
    }
  }
  $g.Dispose()
  $bmp.Save((Join-Path $outDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "wrote $name.png"
}
function Normalize([string[]]$rows){
  $out = @()
  for($y=0;$y -lt 16;$y++){
    $r = if($y -lt $rows.Count){ $rows[$y] } else { '................' }
    if($r.Length -lt 16){ $r = $r + ('.' * (16 - $r.Length)) }
    $out += $r
  }
  return $out
}
function ShiftDown([string[]]$rows){
  $n = Normalize $rows
  $out = @('................') + $n[0..14]
  return ,$out
}

# ---- Slime (Rimuru): translucent blue blob ----
$slimeDown = @(
'................',
'................',
'.....oooo.......',
'...obbbbbbo.....',
'..obbbwbbbbo....',
'.obwwbbbbbbbo...',
'.obwbbbbbbbbbo..',
'.obbbbbbbbbbbbo.',
'obeobbbbbboebo..',
'obeobbbbbboebo..',
'.obbbbbbbbbbb.o.',
'.obbbbbbbbbbbbo.',
'..obbbbbbbbbbo..',
'...oooooooooo...',
'................',
'................')
$slimeSide = @(
'................',
'................',
'.....oooo.......',
'...obbbbbbo.....',
'..obbbwbbbbo....',
'.obwwbbbbbbbo...',
'.obwbbbbbbbbbbo.',
'.obbbbbbbbbbbbo.',
'.obbebbbbbbebo..',
'.obbebbbbbbebo..',
'.obbbbbbbbbbbbo.',
'.obbbbbbbbbbbbo.',
'..obbbbbbbbbbo..',
'...oooooooooo...',
'................',
'................')
Render 'rimuru' $slimeDown $slimeSide '5b9bd5' '3a6ea5' 'ffffff'

# ---- Biped template (humanoids) ----
function Biped([string]$name,[string]$skin,[string]$tunic,[string]$hair){
  $down = @(
  '................',
  '................',
  '.....oooo.......',
  '....ohhhho......',
  '...ohssssho.....',
  '...oseseos......',
  '...ossssss......',
  '....osssso......',
  '...ottttto......',
  '..ottttttto.....',
  '..ottttttto.....',
  '..odtttttdo.....',
  '...od...do......',
  '...od...do......',
  '...ooo.ooo......',
  '................')
  $side = @(
  '................',
  '................',
  '.....oooo.......',
  '....ohhhho......',
  '...ohhhhso......',
  '...ohsoso.......',
  '...ohssso.......',
  '....osssso......',
  '...ottttto......',
  '...ottttto......',
  '....ttttt.......',
  '....odtdto......',
  '....od.do.......',
  '....od..do......',
  '....oo..oo......',
  '................')
  Render $name $down $side $tunic '333344' $hair $skin $hair
}
Biped 'rigurumu' '9ed08a' '7a4a2b' '3d2b1f'   # goblin green skin via tunic? body green
Biped 'shun'     'a8d8b0' '4a6a8a' '2f2f2f'
Biped 'diablo'   '4a3a5a' '222233' '7a3a9a'
Biped 'villager' 'f0c8aa' '8a5a3a' '5a3a1f'
Biped 'dwarf'    'f0c8aa' '3a5a8a' 'aaaaaa'
Biped 'merchant' 'f0c8aa' '3a8a5a' '8a5a3a'
Biped 'goblin'   '8ac07a' 'aa4a3a' '3d2b1f'
Biped 'messenger' 'f0c8aa' '6a3a8a' '2f2f2f'
Biped 'ogre'     '9a4a9a' '553366' '222222'

# ---- Wolf (quadruped) ----
$wolfDown = @(
'................',
'................',
'................',
'................',
'..oo......oo....',
'..obo....obo....',
'...oboooo bo....'.Replace(' ',''),
'..obbbbbbbbbbo..',
'.obbbbbbbbbbbbo.',
'.obeobbbbbobeo..',
'.obbbbbbbbbbbbo.',
'.obbbbbbbbbbbbo.',
'..obboooooobbo..',
'..odo....odo....',
'..ooo....ooo....',
'................')
$wolfSide = @(
'................',
'................',
'................',
'...........oo...',
'..oooooooooboo..',
'.obbbbbbbbbbbdo.',
'.obeobbbbbbdo...',
'.obbbbbbbbbbo...',
'.obbbbbbbbbbo...',
'..obbbbbbbbo....',
'..oddo..oddo....',
'..odo....odo....',
'..ooo....ooo....',
'................',
'................',
'................')
Render 'wolf' $wolfDown $wolfSide '8a8a95' '555560' 'ffffff'
Render 'wolfking' $wolfDown $wolfSide '6a2a3a' '3a1520' 'ffd700'

# ---- Rat ----
$ratDown = @(
'................',
'................',
'................',
'................',
'................',
'................',
'..oo......oo....',
'.oboo....oobo...',
'.obbbbbbbbbbo...',
'.obeobbbobebo...',
'.obbbbbbbbbbo...',
'..obbbbbbbbo....',
'..odo....odo....',
'..ooo....ooo....',
'................',
'................')
$ratSide = $wolfSide
Render 'rat' $ratDown $ratSide 'a5713a' '5a3a1f' 'ffffff'

# ---- Bat ----
$batDown = @(
'................',
'................',
'o..............o',
'oo....oooo....oo',
'ooo.obbbbo...ooo',
'.ooobbbbbooo.oo.',
'..obebebebooo..o',
'...obbbbbooo....',
'...obbbbbo......',
'....obbbo.......',
'.....ooo........',
'................',
'................',
'................',
'................',
'................')
Render 'bat' $batDown $batDown '6a4a8a' '33224a' 'ffffff'

# ---- Frog ----
$frogDown = @(
'................',
'................',
'................',
'................',
'...oo....oo.....',
'..oebo..obeo....',
'..obbo..obbo....',
'.obbbbbbbbbbo...',
'obbbbbbbbbbbbbo.',
'obbbbbbbbbbbbbo.',
'obbbbbbbbbbbbbo.',
'.obbbbbbbbbbbbo.',
'..ooooooooooo...',
'.odo.......odo..',
'.ooo.......ooo..',
'................')
Render 'frog' $frogDown $frogDown '7a4aa0' '4a2a66' 'ffd700'

# ---- Lizard ----
$lizardDown = @(
'................',
'................',
'................',
'....oooo........',
'...obbbbo.......',
'...oebebo.......',
'....obbo........',
'..obbbbbbo......',
'.obbbbbbbbo.....',
'.obbbbbbbbbbo...',
'.obbbbbbbbbbo...',
'..obbbbbbbbo....',
'...oddddo.......',
'...oo..oo.......',
'................',
'................')
Render 'lizard' $lizardDown $lizardDown '4aa05a' '2a6636' 'ffffff'
"done"
