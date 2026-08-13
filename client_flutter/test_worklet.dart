import 'dart:html' as html;
void main() {
  html.AudioContext ctx = html.AudioContext();
  ctx.audioWorklet?.addModule('karaoke_dsp_worklet.js');
}
