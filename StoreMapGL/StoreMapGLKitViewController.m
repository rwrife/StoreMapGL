#import "StoreMapGLKitViewController.h"

typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

CGPoint panCoord;
float sX = 0.0f;
float sY = 0.0f;

float tX = 0.0f;
float tY = 0.0f;

float pS = 1.0f;
float tS = 1.0f;

Vertex storeVertices[1500];

GLushort Indices[4700];

@interface StoreMapGLKitViewController () {
    GLuint _vertexBuffer;
    GLuint _indexBuffer;   
    GLuint _vertexArray;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation StoreMapGLKitViewController
@synthesize context = _context;
@synthesize effect = _effect;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) { }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSDictionary* aisles = [self readStoreCadFile:@"6709.csv"];
    [self setStoreVertices:aisles];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Error");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    [self setup];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragging:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [view addGestureRecognizer:panRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinching:)];
    [view addGestureRecognizer:pinchRecognizer];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self teardown];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)setup {
    [EAGLContext setCurrentContext:self.context];
    
    glCullFace(GL_FRONT);
    glEnable (GL_BLEND);
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glClearDepthf(1.0f);
    glEnable(GL_DEPTH_TEST);
    
    self.effect = [[GLKBaseEffect alloc] init];
    
    NSError * error;    

    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(storeVertices), storeVertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);        
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));
}


- (void)teardown {
    [EAGLContext setCurrentContext:self.context];
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    self.effect = nil;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    glClearColor(0.95, 0.95, 0.95, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self.effect prepareToDraw];
    
    //glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_SHORT, 0);
    glDrawElements(GL_TRIANGLES, 4680, GL_UNSIGNED_SHORT, 0);
}

- (void)update {
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix =  GLKMatrix4MakePerspective(GLKMathDegreesToRadians(45.0f), aspect, 0.0f, 100.0f);
    self.effect.transform.projectionMatrix = projectionMatrix;

    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(sX, 0, (-3.0f + (pS/2)));
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(sY*180), 1, 0, 0);
    //modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(sX*180), 0, 0, 1);
    //modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(45), 0, 0, 1);
    self.effect.transform.modelviewMatrix = modelViewMatrix;
}


#pragma mark - Touch controls

-(void)pinching:(UIPinchGestureRecognizer *)gesture
{
    if(gesture.state == UIGestureRecognizerStateBegan) {
        tS = pS;
    } else if(gesture.state == UIGestureRecognizerStateEnded) { }
    
    pS = tS * gesture.scale;
}

-(void)dragging:(UIPanGestureRecognizer *)gesture
{
    if(gesture.state == UIGestureRecognizerStateBegan)
    {
        panCoord = [gesture locationInView:gesture.view];
        tX = sX;
        tY = sY;
    }
    
    CGPoint newCoord = [gesture locationInView:gesture.view];
    float dX = newCoord.x-panCoord.x;
    float dY = newCoord.y-panCoord.y;
    
    
    int w = self.view.bounds.size.width;
    int h = self.view.bounds.size.height;
    
    sX = tX + dX/w;
    sY = tY + (0 - dY/h);
    
}

#pragma mark - Parse store cad file

-(void) setStoreVertices:(NSDictionary*) aisles {
    NSLog(@"aisle count %d", aisles.count);
    for(int k=0;k<[aisles allKeys].count;k++) { //loop each aisle
        NSString *key = [[aisles allKeys] objectAtIndex:k];
        /*if([key caseInsensitiveCompare:@"FOOTPRINT"] != NSOrderedSame) */{
            NSArray* aisle = (NSArray*) [aisles objectForKey:[[aisles allKeys] objectAtIndex:k]];
            
            for(int i=0;i<4;i++) { //loop each point in aisle
                NSArray* point = [aisle objectAtIndex:i];
                
                float x = [(NSNumber*)[point objectAtIndex:0] floatValue] / 150 - 1;
                float y = [(NSNumber*)[point objectAtIndex:1] floatValue] / 150 - 1;
                //float z = [(NSNumber*)[point objectAtIndex:2] floatValue]; //0
                
                int index = k*8+i;
                
                //set the floor below the surface
                if([key hasPrefix:@"FOOT"]) {
                    [self setPos:storeVertices[index].Position x:x y:y z:-0.1f];
                } else {
                    [self setPos:storeVertices[index].Position x:x y:y z:0.0f];
                }
                
                if([key hasPrefix:@"W"]) {
                    [self setColor:storeVertices[index].Color r:0.282f g:0.282f b:0.282f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.282f g:0.282f b:0.282f a:1.0f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.15f];
                } else if ([key hasPrefix:@"S"]) {
                    [self setColor:storeVertices[index].Color r:0.585f g:0.585f b:0.585f a:0.6f];
                    [self setColor:storeVertices[index+4].Color r:0.585f g:0.585f b:0.585f a:1.6f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.1f];
                } else if([key hasPrefix:@"FOOT"]) {
                    [self setColor:storeVertices[index].Color r:0.382f g:1.382f b:0.382f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.382f g:1.382f b:0.382f a:1.0f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:-0.2f];
                } else {
                    [self setColor:storeVertices[index].Color r:0.921f g:0.146f b:0.139f a:0.8f];
                    [self setColor:storeVertices[index+4].Color r:0.921f g:0.146f b:0.139f a:1.8f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.03f];
                }
            }
            
            //each side = 6 indices
            //6 sides = 36 indices
            
            int b = k*8;
            int t = b+4;
            int i = k*36;
            //int i = k*6;
            
            //bottom
            Indices[i] = b;
            Indices[i+1] = b+1;
            Indices[i+2] = b+2;
            Indices[i+3] = b+2;
            Indices[i+4] = b+3;
            Indices[i+5] = b;
            
            //top
            Indices[i+6] = t;
            Indices[i+7] = t+1;
            Indices[i+8] = t+2;
            Indices[i+9] = t+2;
            Indices[i+10] = t+3;
            Indices[i+11] = t;
            
            //west
            Indices[i+12] = b;
            Indices[i+13] = b+1;
            Indices[i+14] = t+1;
            Indices[i+15] = t;
            Indices[i+16] = t+1;
            Indices[i+17] = b;
            
            //south
            Indices[i+18] = b;
            Indices[i+19] = b+3;
            Indices[i+20] = t;
            Indices[i+21] = t;
            Indices[i+22] = t+3;
            Indices[i+23] = b+3;
            
            //east
            Indices[i+24] = b+2;
            Indices[i+25] = b+3;
            Indices[i+26] = t+3;
            Indices[i+27] = t+3;
            Indices[i+28] = t+2;
            Indices[i+29] = b+2;
            
            //north
            Indices[i+30] = b+2;
            Indices[i+31] = b+1;
            Indices[i+32] = t+1;
            Indices[i+33] = t+1;
            Indices[i+34] = t+2;
            Indices[i+35] = b+2;
            
            
        }
        
        
    }
}

-(void) setPos:(float[3]) point x:(float) x  y:(float) y  z:(float) z {
    point[0] = x;
    point[1] = y;
    point[2] = z;
}

-(void) setColor:(float[4]) color r:(float) r  g:(float) g  b:(float) b a:(float) a {
    color[0] = r;
    color[1] = g;
    color[2] = b;
    color[3] = a;
}

-(NSDictionary*) readStoreCadFile:(NSString*) filename
{
    NSMutableDictionary *aisles = [[NSMutableDictionary alloc] init];
    NSError *errorReading;
    NSStringEncoding encoding;
    NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
    NSString* path = [mainBundlePath stringByAppendingPathComponent:filename];
    NSString* fileContents = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&errorReading];
    NSMutableArray* rows = [NSMutableArray arrayWithArray:[fileContents componentsSeparatedByString:@"\n"]];
    [rows removeObjectAtIndex:0];
    
    for (NSString *row in rows){
        NSArray* columns = [row componentsSeparatedByString:@","];
        if(columns.count > 1) {
            NSMutableArray* rowVertices = [[NSMutableArray alloc] init];
            for(int i=1;i<columns.count;i+=2) {
                GLfloat point[3];
                for(int j=0;j<2;j++) {
                    NSString* col = [columns objectAtIndex:i+j];
                    NSArray* length = [col componentsSeparatedByString:@"-"];
                    int ft = 0;
                    float inch = 0;
                    if(length.count == 2) {
                        ft = [[(NSString*)[length objectAtIndex:0] stringByReplacingOccurrencesOfString:@"'" withString:@""] intValue]; //= 220'
                        inch = [self parseInch:(NSString*)[length objectAtIndex:1]];
                    } else if(length.count == 1) {
                        ft = 0;
                        inch = [self parseInch:(NSString*)[length objectAtIndex:0]];
                    }
                    float convVal = ft + (inch / 12);
                    
                    point[j] = convVal;
                    if(j==1)
                        point[2] = (float) 0.0f;
                }
                
                NSArray* pointArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:point[0]],
                                       [NSNumber numberWithFloat:point[1]],
                                       [NSNumber numberWithFloat:point[2]],nil];
                
                [rowVertices addObject:pointArray];
            }//col loop
            [aisles setValue:rowVertices forKey:(NSString*)[columns objectAtIndex:0]];
        }
        
        
    }// row loop
    return aisles;
}

-(float) parseInch:(NSString*) inch {
    NSArray* inchParts = [inch componentsSeparatedByString:@" "]; //= 6 11/16"
    float frac = 0;
    if(inchParts.count == 2) {
        NSString* fraction = [inchParts objectAtIndex:1];
        fraction = [fraction stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        NSArray* fractionParts = [fraction componentsSeparatedByString:@"/"];
        float dem = [(NSString*)[fractionParts objectAtIndex:1] floatValue];
        float num = [(NSString*)[fractionParts objectAtIndex:0] floatValue];
        frac = num/dem;
    }
    
    return ((float) [(NSString*)[inchParts objectAtIndex:0] floatValue] + frac);
}


@end