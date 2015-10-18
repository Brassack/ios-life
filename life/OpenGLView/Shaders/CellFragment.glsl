//uniform sampler2D SpriteTex;
//
//void main() {
//    gl_FragColor = texture2D(SpriteTex, gl_PointCoord);
//}

//varying lowp float PointSize;
varying lowp vec4 DestinationColor;

void main() {
    gl_FragColor = DestinationColor;
}