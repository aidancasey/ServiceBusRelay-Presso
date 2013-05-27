using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using AutoMapper;
using Cloud.Services;
using Cloud.WebApp.Models;
using Common.DataModel;

namespace Cloud.WebApp.Controllers
{
    public class PersonController : Controller
    {
        public ActionResult Index(PersonSearchViewModel model)
        {
            if (model.SearchButton == null)
            {
                var emptyresults = new PersonSearchViewModel();
                return View(emptyresults);
            }

            var data = new PersonSearchViewModel();
            data.Results = Search(model.SearchCriteria);

            return View(data);
        }

        private Collection<Person> Search(string criteria)
        {
            PersonService svc = new PersonService();
            var result = svc.Search(criteria);

            return Mapper.Map<Collection<PersonDto>, Collection<Person>>(result);
        }


    }
}
