//----------------------------------*-C++-*----------------------------------//
/*!
 * \file   parser/test/tstExpression.cc
 * \author Kent Budge
 * \date   Wed Jul 26 08:15:18 2006
 * \brief  Test the Expression class and expression parsing.
 * \note   Copyright (C) 2016-2017 Los Alamos National Security, LLC.
 *         All rights reserved.
 */
//---------------------------------------------------------------------------//
// $Id$
//---------------------------------------------------------------------------//

// #include <iostream>
// #include <sstream>
// #include <vector>
// #include <stdlib.h>
// #include <cmath>

#include "ds++/ScalarUnitTest.hh"
// #include "ds++/Soft_Equivalence.hh"
#include "ds++/DracoMath.hh"
#include "ds++/Release.hh"
#include "parser/Expression.hh"
#include "parser/String_Token_Stream.hh"

using namespace std;
using namespace rtt_dsxx;
using namespace rtt_parser;

//---------------------------------------------------------------------------//
// TESTS
//---------------------------------------------------------------------------//

void tstExpression(UnitTest &ut) {
  // Create an expression as a String_Token_Stream.

  string const expression_text =
      "(((+1 && 1.3)||!(y<-m))/5+(2>1)*(r/m)*(2.7-1.1*(z/m))^2)*(t/s)";

  String_Token_Stream tokens(expression_text);

  typedef pair<unsigned, Unit> vd;
  map<string, vd> variable_map;

  variable_map["r"] = vd(0, m);
  variable_map["y"] = vd(1, m);
  variable_map["z"] = vd(2, m);
  variable_map["t"] = vd(3, s);

  vector<string> vars(4);
  vars[0] = "r";
  vars[1] = "y";
  vars[2] = "z";
  vars[3] = "t";

  SP<Expression const> expression = Expression::parse(4, variable_map, tokens);

  if (tokens.error_count() == 0 && tokens.lookahead().type() == EXIT) {
    PASSMSG("expression successfully parsed");
  } else {
    FAILMSG("expression NOT successfully parsed");
    cerr << tokens.messages() << endl;
  }

  ostringstream expression_text_copy;
  expression->write(vars, expression_text_copy);

  char const *expression_text_raw =
      "((1&&1.3||!(y<-m))/5+(2>1)*r/m*pow(2.7-1.1*z/m,2))*t/s";
  // changes slightly due to stripping of extraneous whitespace,
  // parentheses, and positive prefix
  if (expression_text_copy.str() == expression_text_raw) {
    PASSMSG("expression successfully rendered as text");
  } else {
    FAILMSG("expression NOT successfully rendered as text");
    cerr << expression_text_raw << endl;
    cerr << expression_text_copy.str() << endl;
  }

#if 0
    // Test calculus

    SP<Expression const> deriv = expression->pd(3);

    ostringstream deriv_text;
    deriv->write(vars, deriv_text);

    expression_text_raw =
        "((1&&1.3||!(y<-m))/5+(2>1)*r/m*pow(2.7-1.1*z/m,2))*t/s";

    if (deriv_text.str()==expression_text_raw)
    {
        PASSMSG("expression successfully derived");
    }
    else
    {
        FAILMSG("expression NOT successfully derived");
        cerr << expression_text_raw << endl;
        cerr << deriv_text.str() << endl;
    }
#endif

  vector<double> xs;

  double x = 1.2;
  double r = x;
  double y = 3.1;
  double z = 0.0;
  double t = 2.8;

  xs.resize(4);
  xs[0] = r;
  xs[1] = y;
  xs[2] = z;
  xs[3] = t;

#if defined(MSVC)
#pragma warning(push)
// warning C4804: '/' : unsafe use of type 'bool' in operation
#pragma warning(disable : 4804)
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wliteral-conversion"
#endif

  if (soft_equiv((*expression)(xs), (((1 && 1.3) || !(y < -1)) / 5. +
                                     (2 > 1) * r * square(2.7 - 1.1 * z)) *
                                        t)) {
    PASSMSG("expression successfully evaluated");
  } else {
    FAILMSG("expression NOT successfully evaluated");
  }

#ifdef __clang__
#pragma clang diagnostic pop
#endif
#if defined(MSVC)
#pragma warning(pop)
#endif

  tokens = string("20*(r>=1.1*m && z<=1.5*m || r>=2.0*m)");

  expression = Expression::parse(4, variable_map, tokens);

  if (expression != SP<Expression>())
    PASSMSG("expression successfully parsed");
  else
    FAILMSG("expression NOT successfully parsed");

  if (soft_equiv((*expression)(xs),
                 20.0 * ((r >= 1.1) && ((z <= 1.5) || (r >= 2.0))))) {
    PASSMSG("expression successfully evaluated");
  } else {
    FAILMSG("expression NOT successfully evaluated");
  }

  {
    ostringstream expression_text_copy;
    expression->write(vars, expression_text_copy);

    char const *expression_text_raw = "20*(r>=1.1*m&&z<=1.5*m||r>=2*m)";
    // changes slightly due to stripping of extraneous whitespace,
    // parentheses, and positive prefix
    if (expression_text_copy.str() == expression_text_raw) {
      PASSMSG("expression successfully rendered as text");
    } else {
      FAILMSG("expression NOT successfully rendered as text");
      cerr << expression_text_raw << endl;
      cerr << expression_text_copy.str() << endl;
    }
  }

  tokens = String_Token_Stream("(1 && (4>=6 || 4>6 || 6<4 || 6<=4 || !0))"
                               "* ( (r/m)^(t/s) + -3 - z/m)");

  expression = Expression::parse(4, variable_map, tokens);

  if (tokens.error_count() == 0 && tokens.lookahead().type() == EXIT) {
    PASSMSG("expression successfully parsed");
  } else {
    FAILMSG("expression NOT successfully parsed");
    cerr << tokens.messages() << endl;
  }

  if (soft_equiv((*expression)(xs), pow(r, t) + -3 - z))
    PASSMSG("expression successfully evaluated");
  else
    FAILMSG("expression NOT successfully evaluated");

  if (!expression->is_constant() && !expression->is_constant(0) &&
      expression->is_constant(1))
    PASSMSG("is_constant good");
  else
    FAILMSG("is_constant NOT good");

  tokens = String_Token_Stream("exp(-0.5*r/m)*(3*cos(2*y/m) + 5*sin(3*y/m))");

  expression = Expression::parse(4, variable_map, tokens);

  if (expression != SP<Expression>())
    PASSMSG("expression successfully parsed");
  else
    FAILMSG("expression NOT successfully parsed");

  if (soft_equiv((*expression)(xs),
                 exp(-0.5 * r) * (3 * cos(2 * y) + 5 * sin(3 * y)))) {
    PASSMSG("expression successfully evaluated");
  } else {
    FAILMSG("expression NOT successfully evaluated");
  }

  {
    ostringstream expression_text_copy;
    expression->write(vars, expression_text_copy);

    char const *expression_text_raw =
        "exp(-0.5*r/m)*(3*cos(2*y/m)+5*sin(3*y/m))";
    // changes slightly due to stripping of extraneous whitespace,
    // parentheses, and positive prefix
    if (expression_text_copy.str() == expression_text_raw) {
      PASSMSG("expression successfully rendered as text");
    } else {
      FAILMSG("expression NOT successfully rendered as text");
      cerr << expression_text_raw << endl;
      cerr << expression_text_copy.str() << endl;
    }
  }

  tokens = String_Token_Stream("log(1.0)");

  expression = Expression::parse(4, variable_map, tokens);

  if (expression != SP<Expression>())
    PASSMSG("expression successfully parsed");
  else
    FAILMSG("expression NOT successfully parsed");

  if (soft_equiv((*expression)(xs), 0.0))
    PASSMSG("expression successfully evaluated");
  else
    FAILMSG("expression NOT successfully evaluated");

  {
    ostringstream expression_text_copy;
    expression->write(vars, expression_text_copy);

    char const *expression_text_raw = "log(1)";
    // changes slightly due to stripping of extraneous whitespace,
    // parentheses, and positive prefix
    if (expression_text_copy.str() == expression_text_raw) {
      PASSMSG("expression successfully rendered as text");
    } else {
      FAILMSG("expression NOT successfully rendered as text");
      cerr << expression_text_raw << endl;
      cerr << expression_text_copy.str() << endl;
    }
  }

  {
    tokens = String_Token_Stream("log(1.0) + cos(2.0) + exp(3.0) + sin(4.0)");

    SP<Expression> expression = Expression::parse(4, variable_map, tokens);

    if (expression->is_constant(0))
      PASSMSG("expression successfully const tested");
    else
      FAILMSG("expression NOT successfully const tested");

    expression->set_units(J);
    if (is_compatible(J, expression->units()))
      PASSMSG("units correctly set");
    else
      FAILMSG("units NOT correctly set");
  }

  {
    tokens = String_Token_Stream(
        "(log(1.0) + cos(2.0) + exp(3.0) + sin(4.0))/(m*s)");

    SP<Expression> expression = Expression::parse(4, variable_map, tokens);

    if (expression->is_constant(0))
      PASSMSG("expression successfully const tested");
    else
      FAILMSG("expression NOT successfully const tested");

    ostringstream expression_text_copy;
    expression->write(vars, expression_text_copy);

    cout << expression_text_copy.str() << endl;

    char const *expression_text_raw = "(log(1)+cos(2)+exp(3)+sin(4))/(m*s)";
    // changes slightly due to stripping of extraneous whitespace,
    // parentheses, and positive prefix
    if (expression_text_copy.str() == expression_text_raw) {
      PASSMSG("expression successfully rendered as text");
    } else {
      FAILMSG("expression NOT successfully rendered as text");
      cerr << expression_text_raw << endl;
      cerr << expression_text_copy.str() << endl;
    }

    expression->set_units(J);
    if (is_compatible(J, expression->units()))
      PASSMSG("units correctly set");
    else
      FAILMSG("units NOT correctly set");
  }
}

//---------------------------------------------------------------------------//
int main(int argc, char *argv[]) {
  ScalarUnitTest ut(argc, argv, release);
  try {
    tstExpression(ut);
  }
  UT_EPILOG(ut);
}

//---------------------------------------------------------------------------//
// end of tstExpression.cc
//---------------------------------------------------------------------------//
