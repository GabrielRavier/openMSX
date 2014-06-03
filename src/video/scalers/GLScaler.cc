#include "GLScaler.hh"
#include "GLPrograms.hh"
#include "gl_vec.hh"

using std::string;
using namespace gl;

namespace openmsx {

GLScaler::GLScaler(const string& progName)
{
	for (int i = 0; i < 2; ++i) {
		string header = string("#define SUPERIMPOSE ")
		              + char('0' + i) + '\n';
		VertexShader   vShader(header, progName + ".vert");
		FragmentShader fShader(header, progName + ".frag");
		program[i].attach(vShader);
		program[i].attach(fShader);
		program[i].bindAttribLocation(0, "a_position");
		program[i].bindAttribLocation(1, "a_texCoord");
		program[i].link();
		program[i].activate();
		glUniform1i(program[i].getUniformLocation("tex"), 0);
		if (i == 1) {
			glUniform1i(program[i].getUniformLocation("videoTex"), 1);
		}
		unifTexSize[i] = program[i].getUniformLocation("texSize");
		glUniformMatrix4fv(program[i].getUniformLocation("u_mvpMatrix"),
		                   1, GL_FALSE, &pixelMvp[0][0]);
	}
}

void GLScaler::uploadBlock(
	unsigned /*srcStartY*/, unsigned /*srcEndY*/,
	unsigned /*lineWidth*/, FrameSource& /*paintFrame*/)
{
}

void GLScaler::drawMultiTex(
	ColorTexture& src,
	unsigned srcStartY, unsigned srcEndY,
	float physSrcHeight, float logSrcHeight,
	unsigned dstStartY, unsigned dstEndY, unsigned dstWidth,
	bool textureFromZero)
{
	src.bind();
	// Note: hShift is pre-divided by srcWidth, while vShift will be divided
	//       by srcHeight later on.
	// Note: The coordinate is put just past zero, to avoid fract() in the
	//       fragment shader to wrap around on rounding errors.
	float hShift = textureFromZero ? 0.501f / dstWidth : 0.0f;
	float vShift = textureFromZero ? 0.501f * (
		float(srcEndY - srcStartY) / float(dstEndY - dstStartY)
		) : 0.0f;

	// vertex positions
	vec2 pos[4] = {
		vec2(       0, dstStartY),
		vec2(dstWidth, dstStartY),
		vec2(dstWidth, dstEndY  ),
		vec2(       0, dstEndY  ),
	};
	// texture coordinates, X-coord shared, Y-coord separate for tex0 and tex1
	float tex0StartY = (srcStartY + vShift) / physSrcHeight;
	float tex0EndY   = (srcEndY   + vShift) / physSrcHeight;
	float tex1StartY = (srcStartY + vShift) / logSrcHeight;
	float tex1EndY   = (srcEndY   + vShift) / logSrcHeight;
	vec3 tex[4] = {
		vec3(0.0f + hShift, tex0StartY, tex1StartY),
		vec3(1.0f + hShift, tex0StartY, tex1StartY),
		vec3(1.0f + hShift, tex0EndY  , tex1EndY  ),
		vec3(0.0f + hShift, tex0EndY  , tex1EndY  ),
	};

	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, pos);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, tex);
	glEnableVertexAttribArray(0);
	glEnableVertexAttribArray(1);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}

} // namespace openmsx
