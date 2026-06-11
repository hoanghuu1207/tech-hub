import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("access_token")?.value;
  const { pathname } = request.nextUrl;

  // Public routes — skip auth check
  const isLoginPage = pathname === "/login";

  // If no token and trying to access protected pages → redirect to login
  if (!token && !isLoginPage) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // If has token and on login page → redirect to dashboard
  if (token && isLoginPage) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  // Root "/" → redirect to dashboard
  if (pathname === "/") {
    if (token) {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all paths except:
     * - api routes
     * - _next (static assets)
     * - favicon.ico, images, etc.
     */
    "/((?!api|_next/static|_next/image|favicon.ico|logo.svg).*)",
  ],
};
