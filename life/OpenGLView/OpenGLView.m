//
//  OpenGLView.m
//  life
//
//  Created by Dmitrii Platov on 10/15/15.
//  Copyright © 2015 dplatov. All rights reserved.
//

#import "OpenGLView.h"
#import <GLKit/GLKit.h>

#define FIELD_HEIGHT 10
#define FIELD_WIDTH 10

//const GLuint field[FIELD_HEIGHT*FIELD_WIDTH];

typedef struct {
    GLfloat position[3];
    GLfloat color[4];
} GLVertex;


typedef struct{
    GLVertex vertices[2];
    GLuint vertextBuffer;
} GLLine;


@interface OpenGLView()
{
//buffers
    GLuint colorRenderBuffer;
    GLuint depthStencilBuffer;
    GLuint linesIndexBuffer;
    GLuint linesIndices[2];
    
    
    GLuint* cellsIndices;
    GLuint cellsVertextBuffer;
    GLuint cellsIndexBuffer;
//shaders
    GLuint lineProgramHandle;
    GLuint linePositionSlot;
    GLuint lineColorSlot;
    
    GLuint cellProgramHandle;
    GLuint cellPositionSlot;
    GLuint cellColorSlot;
    GLuint cellSizeSlot;

}
//data
@property (nonatomic ,readonly) GLuint *field;

@property GLVertex* cells;

@property (nonatomic) GLLine* lines;

//visulisation
@property (nonatomic, readonly) CAEAGLLayer* eaglLayer;

@property (nonatomic) CADisplayLink* displayLink;

@property (nonatomic) EAGLContext* context;

@end

@implementation OpenGLView

@synthesize field=_field, lines=_lines;

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super initWithCoder:aDecoder]){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [self setupLayer];
//        self.context;
//        [self setupDepthBuffer];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self compileShaders];
        [self setupVBOs];
//        self.lines;
#warning test code
        self.field;
        [self setupDisplayLink];
    }
    
    return self;
}

#pragma mark setup
- (void)setupLayer{
    self.eaglLayer.opaque = YES;
}

- (void)setupRenderBuffer {
    EAGLContext* ctx = self.context;
    if(!ctx){
        exit(1);
    }
    
    glGenRenderbuffers(1, &colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
//    glGenRenderbuffers(1, &depthStencilBuffer);
//    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
    [ctx renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

- (void)setupFrameBuffer {
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderBuffer);
}

- (void)setupVBOs {
    
    linesIndices[0] = 0;
    linesIndices[1] = 1;
    
    
    glGenBuffers(1, &linesIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, linesIndexBuffer);
    
    glGenBuffers(1, &cellsIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cellsIndexBuffer);
    
//    //    GLuint _vertexBuffer;
//    glGenBuffers(1, &_vertexBuffer);
//    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
//    //    glBufferData(GL_ARRAY_BUFFER, sizeof(_vertices), _vertices, GL_STATIC_DRAW);
//    
//    //    GLuint _indexBuffer;
//    glGenBuffers(1, &_indexBuffer);
//    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
//    //    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(_indices), _indices, GL_STATIC_DRAW);
//    ///
//    glGenBuffers(1, &_vertexBuffer2);
//    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer2);
//    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices2), Vertices2, GL_STATIC_DRAW);
//    
//    glGenBuffers(1, &_indexBuffer2);
//    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer2);
//    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices2), Indices2, GL_STATIC_DRAW);
//    //
//    
//    glGenBuffers(1, &_vertexBuffer3);
//    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer3);
//    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices3), Vertices3, GL_STATIC_DRAW);
//    
//    glGenBuffers(1, &_indexBuffer3);
//    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer3);
//    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices3), Indices3, GL_STATIC_DRAW);
}

- (void)compileShaders {

    GLuint vertexShader = [self compileShader:@"LineVertex" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"LineFragment" withType:GL_FRAGMENT_SHADER];
    
    lineProgramHandle = glCreateProgram();
    glAttachShader(lineProgramHandle, vertexShader);
    glAttachShader(lineProgramHandle, fragmentShader);
    glLinkProgram(lineProgramHandle);
    
    
    // 3
    GLint linkSuccess;
    glGetProgramiv(lineProgramHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(lineProgramHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(lineProgramHandle);
    linePositionSlot = glGetAttribLocation(lineProgramHandle, "Position");
    lineColorSlot = glGetAttribLocation(lineProgramHandle, "SourceColor");
    glEnableVertexAttribArray(linePositionSlot);
    glEnableVertexAttribArray(lineColorSlot);
    

    
    vertexShader = [self compileShader:@"CellVertex" withType:GL_VERTEX_SHADER];
    fragmentShader = [self compileShader:@"CellFragment" withType:GL_FRAGMENT_SHADER];
    
    cellProgramHandle = glCreateProgram();
    glAttachShader(cellProgramHandle, vertexShader);
    glAttachShader(cellProgramHandle, fragmentShader);
    glLinkProgram(cellProgramHandle);
    
    
    // 3
    glGetProgramiv(cellProgramHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(cellProgramHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(cellProgramHandle);
    cellPositionSlot = glGetAttribLocation(cellProgramHandle, "Position");
    cellColorSlot = glGetAttribLocation(cellProgramHandle, "SourceColor");
    cellSizeSlot = glGetUniformLocation(cellProgramHandle, "PointSize");
    glEnableVertexAttribArray(cellPositionSlot);
    glEnableVertexAttribArray(cellColorSlot);
}

- (void)setupDisplayLink{
    if(_displayLink){
        return;
    }
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark getter
- (CAEAGLLayer*)eaglLayer{
    return (CAEAGLLayer*)self.layer;
}

- (EAGLContext*)context{
    if(_context){
        return _context;
    }
    
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
    
    
    
    return _context;
}

- (CADisplayLink*)displayLink{
    if(_displayLink){
        return _displayLink;
    }
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    return _displayLink;
}

- (GLuint*)field{
    if(_field){
        return _field;
    }
    
    _field = calloc(FIELD_HEIGHT*FIELD_WIDTH, sizeof(GLuint));
    
    
#warning test code
    _field[0] = 1;
    _field[10] = 1;
    _cellCount = 2;
    
    _cells = calloc(_cellCount, sizeof(GLVertex));
    
    GLfloat horisontalSpace = 2.0/(FIELD_WIDTH + 1);
    GLfloat verticalSpace = 2.0/(FIELD_HEIGHT + 1);
    
    NSUInteger i = 10;
    NSUInteger column = i - FIELD_WIDTH*(i/FIELD_WIDTH);
    NSUInteger row = i/FIELD_WIDTH;
    
    GLfloat left = (column + 1)*horisontalSpace - 1.0;
    GLfloat top = (row + 1)*verticalSpace - 1.0;

    
    _cells[0] = (GLVertex){{left,top,0.0},{.0, 1.0, .0, 1.0}};
    
    
    i = 3;
    
    column = i - FIELD_WIDTH*(i/FIELD_WIDTH);
    
    row = i/FIELD_WIDTH;
    left = (column + 1)*horisontalSpace - 1.0;
    top = (row + 1)*verticalSpace - 1.0;
    
    _cells[1] = (GLVertex){{left,top,0.0},{.0, 1.0, .0, 1.0}};
    
    
    glGenBuffers(1, &cellsVertextBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, cellsVertextBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(_cells), _cells, GL_STATIC_DRAW);
    
    cellsIndices = malloc(sizeof(GLuint)*_cellCount);
    for(GLuint i = 0; i<_cellCount; ++i){
        cellsIndices[i] = i;
    }
    
    return _field;
}

- (GLLine*)lines{
    if(_lines){
        return _lines;
    }
    
    _lines = malloc(sizeof(GLLine)*FIELD_WIDTH*FIELD_HEIGHT);
    
    GLfloat horisontalSpace = 2.0/(FIELD_WIDTH + 1);
    GLfloat verticalSpace = 2.0/(FIELD_HEIGHT + 1);

    
    for(NSUInteger i = 0; i<FIELD_WIDTH; ++i){
        //start
        _lines[i].vertices[0].position[0] = (i + 1)*horisontalSpace - 1.0;
        _lines[i].vertices[0].position[1] = - 1.0;
        _lines[i].vertices[0].position[2] = 0.0;
        //end
        _lines[i].vertices[1].position[0] = _lines[i].vertices[0].position[0];
        _lines[i].vertices[1].position[1] = 1.0;
        _lines[i].vertices[1].position[2] = 0.0;
    }
    
    for(NSUInteger i = FIELD_WIDTH; i<FIELD_HEIGHT+FIELD_WIDTH; ++i){
        NSUInteger leftIndex = i - FIELD_WIDTH;
        //start
        _lines[i].vertices[0].position[0] = - 1.0;
        _lines[i].vertices[0].position[1] = (leftIndex + 1)*verticalSpace - 1.0;
        _lines[i].vertices[0].position[2] = 0.0;
        //end
        _lines[i].vertices[1].position[0] = 1.0;
        _lines[i].vertices[1].position[1] = _lines[i].vertices[0].position[1];
        _lines[i].vertices[1].position[2] = 0.0;
    }
    
    //color
    for(NSUInteger i = 0; i<FIELD_HEIGHT+FIELD_WIDTH; ++i){
        
        _lines[i].vertices[0].color[0] = 1.0;
        _lines[i].vertices[0].color[1] = 1.0;
        _lines[i].vertices[0].color[2] = 1.0;
        _lines[i].vertices[0].color[3] = 1.0;
        
        _lines[i].vertices[1].color[0] = 1.0;
        _lines[i].vertices[1].color[1] = 1.0;
        _lines[i].vertices[1].color[2] = 1.0;
        _lines[i].vertices[1].color[3] = 1.0;

        
        glGenBuffers(1, &_lines[i].vertextBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _lines[i].vertextBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(_lines), _lines, GL_STATIC_DRAW);
    }
    
    return _lines;
}

#pragma mark render
- (void)render:(CADisplayLink*)sender{
//    NSLog(@"timestamp - %f", sender.timestamp);
    glClearColor(.0, .0, .0, .0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);

    
    
    glUseProgram(lineProgramHandle);
    

    for(NSUInteger i = 0; i<FIELD_HEIGHT + FIELD_WIDTH; ++i){
        
        GLLine line = self.lines[i];
        glBindBuffer(GL_ARRAY_BUFFER, line.vertextBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, linesIndexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(self.lines[i].vertices), self.lines[i].vertices, GL_STATIC_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(linesIndices), linesIndices, GL_STATIC_DRAW);
        

        glVertexAttribPointer(linePositionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), 0);
        glVertexAttribPointer(lineColorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (GLvoid*)(sizeof(float) * 3));
        glEnableVertexAttribArray(linePositionSlot);
        glEnableVertexAttribArray(lineColorSlot);
        
        glDrawElements(GL_LINES, sizeof(linesIndices)/sizeof(*linesIndices), GL_UNSIGNED_INT, 0);
    }
    
    
    glUseProgram(cellProgramHandle);
    
    
    glBindBuffer(GL_ARRAY_BUFFER, cellsVertextBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cellsIndexBuffer);
    glBufferData(GL_ARRAY_BUFFER, _cellCount*sizeof(*self.cells), self.cells, GL_STATIC_DRAW);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(cellsIndices), cellsIndices, GL_STATIC_DRAW);
    
    
    glVertexAttribPointer(cellPositionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), 0);
    glVertexAttribPointer(cellColorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (GLvoid*)(sizeof(float) * 3));
    glUniform1f(cellSizeSlot, 5.0);
    glEnableVertexAttribArray(cellPositionSlot);
    glEnableVertexAttribArray(cellColorSlot);
    
    glDrawElements(GL_POINTS, (GLsizei)_cellCount, GL_UNSIGNED_INT, 0);

    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark helper
- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    // 1
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 2
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4
    glCompileShader(shaderHandle);
    
    // 5
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
}

#pragma mark lifecycle
- (void)dealloc{
    [self.displayLink invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
//    self.displayLink = nil;
    //    GLuint tId = _gridTexture.textureID;
    //    glDeleteTextures(1, &tId);
    //    glDeleteBuffers(1, &_colorRenderBuffer);
    //    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidEnterBackground:(NSNotification*)note{
    
}

- (void)appWillEnterForeground:(NSNotification*)note{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
