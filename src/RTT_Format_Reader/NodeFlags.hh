//----------------------------------*-C++-*----------------------------------//
/*!
 * \file   RTT_Format_Reader/NodeFlags.hh
 * \author B.T. Adams
 * \date   Wed Jun 7 10:33:26 2000
 * \brief  Header file for RTT_Format_Reader/NodeFlags class.
 * \note   Copyright (C) 2016-2019 Triad National Security, LLC.
 *         All rights reserved. */
//---------------------------------------------------------------------------//

#ifndef __RTT_Format_Reader_NodeFlags_hh__
#define __RTT_Format_Reader_NodeFlags_hh__

#include "Dims.hh"
#include "Flags.hh"
#include <memory>

namespace rtt_RTT_Format_Reader {

//============================================================================//
/*!
 * \class NodeFlags
 * \brief Controls parsing, storing, and accessing the data specific to the
 *        node flags block of the mesh file.
 */
//============================================================================//
class NodeFlags {
  // typedefs
  typedef std::ifstream ifstream;
  typedef std::string string;

  const Dims &dims;
  std::vector<std::shared_ptr<Flags>> flagTypes;

public:
  explicit NodeFlags(const Dims &dims_)
      : dims(dims_), flagTypes(dims.get_nnode_flag_types()) {}
  ~NodeFlags() {}

  void readNodeFlags(ifstream &meshfile);

private:
  void readKeyword(ifstream &meshfile);
  void readFlagTypes(ifstream &meshfile);
  void readEndKeyword(ifstream &meshfile);

public:
  /*!
   * \brief Validates the specified node flag type and number.
   * \param flagtype Node flag type number.
   * \param flag Flag number.
   * \return The existance of the node flag type and number.
   */
  bool allowed_flag(size_t flagtype, int flag) const {
    Insist(flagtype <= dims.get_nnode_flag_types() - 1,
           "Invalid node flag type number!");
    return flagTypes[flagtype]->allowed_flag(flag);
  }

  /*!
   * \brief Returns the name of specified node flag type.
   * \param flagtype Node flag type number.
   * \return The node flag type name.
   */
  string get_flag_type(size_t flagtype) const {
    Insist(flagtype <= dims.get_nnode_flag_types() - 1,
           "Invalid node flag type number!");
    return flagTypes[flagtype]->getFlagType();
  }

  int get_flag_type_index(string &desired_flag_type) const;

  /*!
   * \brief Returns the node flag number associated with the specified node flag
   *        type and node flag index.
   * \param flagtype Node flag type number.
   * \param flag_index Node flag index.
   * \return The node flag number.
   */
  int get_flag_number(size_t flagtype, size_t flag_index) const {
    Insist(flagtype <= dims.get_nnode_flag_types() - 1,
           "Invalid node flag type number!");
    Insist(flag_index <= flagTypes[flagtype]->getFlagSize() - 1,
           "Invalid node flag number index number!");
    return flagTypes[flagtype]->getFlagNumber(flag_index);
  }

  /*!
   * \brief Returns the number of node flags for the specified node flag type.
   * \param flagtype Node flag type number.
   * \return The number of node flags.
   */
  size_t get_flag_size(size_t flagtype) const {
    Insist(flagtype <= dims.get_nnode_flag_types() - 1,
           "Invalid node flag type number!");
    return flagTypes[flagtype]->getFlagSize();
  }

  /*!
   * \brief Returns the node flag name associated with the specified node flag
   *        type and node flag type index.
   * \param flagtype Node flag type number.
   * \param flag_index Node flag index.
   * \return The node flag name.
   */
  string get_flag_name(size_t flagtype, size_t flag_index) const {
    Insist(flagtype <= dims.get_nnode_flag_types() - 1,
           "Invalid node flag type number!");
    Insist(flag_index <= flagTypes[flagtype]->getFlagSize() - 1,
           "Invalid node flag name index number!");
    return flagTypes[flagtype]->getFlagName(flag_index);
  }
};

} // end namespace rtt_RTT_Format_Reader

#endif // __RTT_Format_Reader_NodeFlags_hh__

//---------------------------------------------------------------------------//
// end of RTT_Format_Reader/NodeFlags.hh
//---------------------------------------------------------------------------//
