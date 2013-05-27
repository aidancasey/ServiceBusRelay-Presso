using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using AutoMapper;
using Cloud.Services;
using Cloud.WebApp.Models;
using Common.DataModel;

namespace Cloud.WebApp.Controllers
{
    public class PhotoController : Controller
    {

        public ActionResult Image(string name)
        {
         //   string name = "foo";

            ImageService svc = new ImageService();
            var imageStream = svc.DonwloadImage(name);

            return File(imageStream, "image/png");
        }


        public ActionResult Index(ImageSearchViewModel model)
        {
            if (model.SearchButton == null)
            {
                return View();
            }

            else
            {
                return View(new ImageSearchViewModel());
            }
        }


    }
}
