//------------------------------------------------------------------------------
// <auto-generated>
//    This code was generated from a template.
//
//    Manual changes to this file may cause unexpected behavior in your application.
//    Manual changes to this file will be overwritten if the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

namespace OnPremise.DataAccess
{
    using System;
    using System.Collections.Generic;
    
    public partial class CountryRegion
    {
        public CountryRegion()
        {
            this.StateProvinces = new HashSet<StateProvince>();
        }
    
        public string CountryRegionCode { get; set; }
        public string Name { get; set; }
        public System.DateTime ModifiedDate { get; set; }
    
        public virtual ICollection<StateProvince> StateProvinces { get; set; }
    }
}
