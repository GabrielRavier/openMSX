#ifndef GLRGBSCALER_HH
#define GLRGBSCALER_HH

#include "GLScaler.hh"
#include "GLUtil.hh"
#include "noncopyable.hh"

namespace openmsx {

class RenderSettings;

class GLRGBScaler : public GLScaler, private noncopyable
{
public:
	GLRGBScaler(RenderSettings& renderSettings, GLScaler& fallback);

	virtual void scaleImage(
		gl::ColorTexture& src, gl::ColorTexture* superImpose,
		unsigned srcStartY, unsigned srcEndY, unsigned srcWidth,
		unsigned dstStartY, unsigned dstEndY, unsigned dstWidth,
		unsigned logSrcHeight);

private:
	RenderSettings& renderSettings;
	GLScaler& fallback;
	int unifCnsts[2];
};

} // namespace openmsx

#endif // GLSIMPLESCALER_HH
