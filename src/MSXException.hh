#ifndef MSXEXCEPTION_HH
#define MSXEXCEPTION_HH

#include "string_view.hh"
#include "strCat.hh"

namespace openmsx {

class MSXException
{
public:
	explicit MSXException() = default;

	explicit MSXException(std::string message_)
            : message(std::move(message_)) {}

        template<typename... Args>
        explicit MSXException(Args&&... args)
            : message(strCat(std::forward<Args>(args)...))
        {
        }

	const std::string& getMessage() const {
		return message;
	}

private:
	const std::string message;
};

class FatalError
{
public:
	explicit FatalError(std::string message_)
            : message(std::move(message_)) {}

        template<typename... Args>
        explicit FatalError(Args&&... args)
            : message(strCat(std::forward<Args>(args)...))
        {
        }

	const std::string& getMessage() const {
		return message;
	}

private:
	const std::string message;
};

} // namespace openmsx

#endif
