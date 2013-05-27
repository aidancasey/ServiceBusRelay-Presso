﻿using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Web;

namespace Cloud.WebApp.Models
{
    public class PersonSearchViewModel
    {
        public Collection<Person> Results { get; set; }
        public string SearchCriteria { get; set; }
        public string SearchButton { get; set; }
    }
}