module Graphics.FunGL.ShaderProgram
  ( AttrLoc(..)
  , UniformLoc(..)
  , ShaderProgram(..)

  , makeShaderProgram
  , bindProgram
  , deleteProgram

  , bindAttribLocation
  , getAttribLocation
  , getUniformLocation

  , bindUniform44f
  , bindUniform33f
  , bindUniform22f
  ) where

import Foreign.Ptr
import Foreign.C.String
import Foreign.Marshal
import Foreign.Storable
import Control.Exception
import Control.Monad (when, forM_, liftM)

import Linear

import Graphics.GL

newtype AttrLoc = AttrLoc { fromAttrLoc :: GLuint }
newtype UniformLoc = UniformLoc { fromUniformLoc :: GLint }

newtype ShaderProgram = ShaderProgram { fromShaderProgram :: GLuint }

makeShaderProgram :: String -> String -> IO ShaderProgram
makeShaderProgram vertexShaderSrc fragmentShaderSrc = do
  vertexShaderId <- compileShader vertexShaderSrc GL_VERTEX_SHADER
  fragmentShaderId <- compileShader fragmentShaderSrc GL_FRAGMENT_SHADER

  programId <- glCreateProgram

  glAttachShader programId vertexShaderId
  glAttachShader programId fragmentShaderId

  glLinkProgram programId

  linkStatus <- liftM toBool $
    alloca (\ptr -> glGetProgramiv programId GL_LINK_STATUS ptr >> peek ptr)

  infoLogLen <- alloca (\ptr -> glGetProgramiv programId GL_INFO_LOG_LENGTH ptr >> peek ptr)

  when (infoLogLen > 0) $
    allocaArray0 (fromIntegral infoLogLen) $ \msgPtr -> do
       _ <- glGetShaderInfoLog programId infoLogLen nullPtr msgPtr
       msg <- peekCString msgPtr
       (if linkStatus then putStrLn else fail) msg

  glDeleteShader vertexShaderId
  glDeleteShader fragmentShaderId
  
  return (ShaderProgram programId)

compileShader :: String -> GLenum -> IO GLuint
compileShader src shaderType = do
  -- denerate shader id
  shaderId <- glCreateShader shaderType

  withCString src $ \srcPtr ->
    with srcPtr $ \srcPtrPtr ->
       glShaderSource shaderId 1 srcPtrPtr nullPtr

  -- compile shader
  glCompileShader shaderId

  -- get compilation status
  compileStatus <- liftM toBool $
    alloca (\ptr ->
              glGetShaderiv shaderId GL_COMPILE_STATUS ptr >> peek ptr)

  infoLogLen <- alloca (\ptr ->
                          glGetShaderiv shaderId GL_INFO_LOG_LENGTH ptr >> peek ptr)

  when (infoLogLen > 0) $
    allocaArray0 (fromIntegral infoLogLen) $ \msgPtr -> do
       _ <- glGetShaderInfoLog shaderId infoLogLen nullPtr msgPtr
       msg <- peekCString msgPtr
       (if compileStatus then putStrLn else fail) msg

  return shaderId
  
-- | Bind program to current context
bindProgram :: ShaderProgram -> IO ()
bindProgram = glUseProgram . fromShaderProgram

-- | Delete program
deleteProgram :: ShaderProgram -> IO ()
deleteProgram = glDeleteProgram . fromShaderProgram

-- | Bind attribute name to specified location
bindAttribLocation :: ShaderProgram -> AttrLoc -> String -> IO ()
bindAttribLocation prog loc name = do
  withCString name $ glBindAttribLocation (fromShaderProgram prog) (fromAttrLoc loc)

-- | Bind attribute name to location specified by OpenGL
getAttribLocation :: ShaderProgram -> String -> IO AttrLoc
getAttribLocation prog name = do
  loc <- withCString name $ glGetAttribLocation $ fromShaderProgram prog
  if loc < 0
    then error $ "`" ++ name ++ "` can not be found!"
    else return $ AttrLoc (fromIntegral loc)

-- | Bind uniform name to location specified by OpenGL
getUniformLocation :: ShaderProgram -> String -> IO UniformLoc
getUniformLocation prog name = do
  loc <- withCString name $ glGetUniformLocation $ fromShaderProgram prog
  if loc < 0
    then error $ "`" ++ name ++ "` can not be found!"
    else return $ UniformLoc (fromIntegral loc)


-- | Uniforms

castMatComponent :: Ptr (t (f a)) -> Ptr a
castMatComponent = castPtr

castVecComponent :: Ptr (t a) -> Ptr a
castVecComponent = castPtr

-- | bind uniform 4f (4x4 matrix) , fromBool True for because row-first
bindUniform44f :: M44 Float -> UniformLoc -> IO ()
bindUniform44f matrix loc = do
  with matrix $ glUniformMatrix4fv (fromUniformLoc loc) 1 (fromBool False) . castMatComponent

bindUniform33f :: M33 Float -> UniformLoc -> IO ()
bindUniform33f matrix loc = do
  with matrix $ glUniformMatrix3fv (fromUniformLoc loc) 1 (fromBool False) . castMatComponent

bindUniform22f :: M22 Float -> UniformLoc -> IO ()
bindUniform22f matrix loc = do
  with matrix $ glUniformMatrix2fv (fromUniformLoc loc) 1 (fromBool False) . castMatComponent
